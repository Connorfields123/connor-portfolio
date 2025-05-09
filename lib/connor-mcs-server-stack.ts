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

        // arm linux 2 server with 2 vCPU and 8G Memory
        const minecraftServer = new ec2.Instance(this, 'MinecraftInstance', {
            vpc,
            instanceType: new ec2.InstanceType('t4g.large'),
            machineImage: ec2.MachineImage.genericLinux({
              'us-east-1': 'ami-0a0c8eebcdd6dcbd0',
            }),
            vpcSubnets: {
              subnetType: ec2.SubnetType.PUBLIC,
            },
            instanceName: 'public-minecraft-server',
            keyName: "mcserver"
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