import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as ssm from 'aws-cdk-lib/aws-ssm';

export class ConnorPortfolioStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // create s3 bucket to backup server data to
    const serverBackupBucket = new s3.Bucket(this, "server-backup-bucket", {
      bucketName: "connor-mcs-backup-us-east-1-bucket",
      versioned: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN
    });

    // export bucket arn incase needed in other stacks
    new ssm.StringParameter(this, "bucket-arn", {
      parameterName: "bucket-arn",
      stringValue: serverBackupBucket.bucketArn
    });
  }
}
