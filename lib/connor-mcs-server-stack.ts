import * as cdk from 'aws-cdk-lib';
import {Construct} from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ssm from 'aws-cdk-lib/aws-ssm';
import * as fs from "fs";
import * as iam from 'aws-cdk-lib/aws-iam';

export class ConnorMcsServer extends cdk.Stack {

    constructor(scope: Construct, id: string, props?: cdk.StackProps) {
        super(scope, id, props);

        // use default vpc
        const vpc = ec2.Vpc.fromLookup(this, "default-vpc", {isDefault: true});

        const securityGroup = new ec2.SecurityGroup(this, 'server-sg', {
            vpc: vpc,
            allowAllOutbound: true
        });

        securityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(25565), 'Allow Minecraft Connection');
        securityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(22), 'Allow SSH Connection');

        // arm linux 2 server with 2 vCPU and 8G Memory
        const minecraftServer = new ec2.Instance(this, 'MinecraftInstance', {
            vpc,
            instanceType: new ec2.InstanceType('t4g.large'),
            machineImage: ec2.MachineImage.latestAmazonLinux2({
              cpuType: ec2.AmazonLinuxCpuType.ARM_64,
            }),
            vpcSubnets: {
              subnetType: ec2.SubnetType.PUBLIC,
            },
            instanceName: 'public-minecraft-server',
            keyPair: ec2.KeyPair.fromKeyPairName(this, 'ImportedKeyPair', "mcserver")
        });

        // export instance id incase needed in other stacks
        new ssm.StringParameter(this, "instance-id-ssm-parameter", {
            parameterName: "mcs-instance-id",
            stringValue: minecraftServer.instanceId
        });

        // add userdata script for automatic minecraft server setup + jobs to backup saves to s3 upon server shutdown
        const userDataScript = fs.readFileSync('minecraft-userdata.sh', 'utf8');
        minecraftServer.addUserData(userDataScript);

        // open minecraft connection port
        minecraftServer.connections.allowFromAnyIpv4(ec2.Port.tcp(25565), 'Allow Minecraft Connections');

        // give server full access to s3
        minecraftServer.role.addManagedPolicy(
            iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonS3FullAccess') // or create a tighter custom policy
        );
    }
}