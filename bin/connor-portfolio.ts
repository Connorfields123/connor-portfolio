#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { ConnorPortfolioStack } from '../lib/connor-s3-bucket-stack';
import { ConnorMcsServer } from '../lib/connor-mcs-server-stack';

const app = new cdk.App();

const s3Bucket = new ConnorPortfolioStack(app, 'ConnorPortfolioStack', {
  env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },
});

const server = new ConnorMcsServer(app, 'ConnorMCServerStack', {
  env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },

});

s3Bucket;
server.addDependency(s3Bucket);