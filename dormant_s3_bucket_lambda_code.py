import boto3
import pandas as pd
import time
import sys
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
athena_client = boto3.client('athena')
sns_client = boto3.client('sns')

def publish_sns(snsMessage):
    snsTopicArn = os.environ['SNS_Topic_Arn']
    snsSubject = "Dormant S3 Buckets Notification"
    sns_client.publish(TopicArn=snsTopicArn, Subject=snsSubject, Message=snsMessage)


def read_query_csv(bucket_name, file_name):
    ### Sleep for a period, to allow Athena to send the file to S3. Else, might encounter "key not found" error.
    time.sleep(5)
    
    try:
        resp = s3_client.get_object(Bucket=bucket_name, Key=file_name)
        
    except Exception as e:
        logger.info(e)
        # https://dzone.com/articles/why-you-should-never-ever-logger.info-in-a-lambda-functi
        sys.exit(f"Do manually check if the file exist in the path: {file_name}.\n \
            If it exist, increase the sleep duration above accordingly. \
            Else, try running your SQL query manually on Athena to check if it encounters any error.")
        
    df = pd.read_csv(resp['Body'], sep=',')
    logger.info(df.head())
    
    df['last_accessed_date'] = df['last_accessed_date'].str[:10]
    df['todays_date'] = pd.Timestamp.today().strftime('%Y-%m-%d')
    
    df['last_accessed_date']= pd.to_datetime(df['last_accessed_date'])
    df['todays_date']= pd.to_datetime(df['todays_date'])
    # df.info()
    
    df['Days_since_last_access'] = (df['todays_date'] - df['last_accessed_date']).dt.days
    df = df.drop(['todays_date'], axis=1)
    
    limit = int(os.environ['Limit'])
    
    df_alarm = df.loc[(df['Days_since_last_access'] >= limit)]
    
    if len(df_alarm.index):
        each = ""
        for i, j in df_alarm.iterrows():
            str_j = str(j)
            cut = str_j.rfind("\n")
            modified_j = str_j[:cut]
            each = f"{each}\n{modified_j}\n"
            
        text_to_sns = f"There are {len(df_alarm.index)} S3 buckets that were not accessed in the last {limit} days or more.\n{each}"
        publish_sns(text_to_sns)
    else:
        text_to_sns = f"All S3 buckets were accessed within the past {limit} days."
        publish_sns(text_to_sns)


def lambda_handler(event, context):
    
    ### Query string to execute
    # query = "SELECT bucket_name , MAX(parse_datetime(requestdatetime,'dd/MMM/yyyy:HH:mm:ss Z')) AS last_accessed_date \
    #     FROM s3_access_logs_db.mybucket_logs \
    #     WHERE NOT key='-' \
    #     GROUP BY bucket_name;"

    query = os.environ['Query']
        
    ### Database to execute the query against
    database = "s3_access_logs_db"
    
    try:
        # Start the query execution
        response_start = athena_client.start_query_execution(
            QueryString=query,
            QueryExecutionContext={
                'Database': database
            },
            ResultConfiguration={
                'OutputLocation': os.environ['S3PathAthenaQuery']
            }
        )
        
        HTTPStatusCode = response_start['ResponseMetadata']['HTTPStatusCode']
        if HTTPStatusCode != 200:
            logger.info(f"HTTPStatusCode is not 200 for the 'start_query_execution' command, it is {HTTPStatusCode}.")
            return("Expected a different value for HTTPStatusCode.")
    
    except Exception as e:
        logger.info(e)
        return("Error encountered when running the 'start_query_execution' command.")
    
    logger.info(f"The response_start is: {response_start}")
    
    QueryExecutionId = response_start["QueryExecutionId"]
    logger.info(f"The QueryExecutionId is: {QueryExecutionId}")
    
    ### get_query_execution to obtain the s3 file where the results are stored
    response_get = athena_client.get_query_execution(QueryExecutionId=QueryExecutionId)
    logger.info(f"The response_get is: {response_get}")
    
    OutputLocation = response_get["QueryExecution"]["ResultConfiguration"]["OutputLocation"]
    logger.info(f"The OutputLocation is: {OutputLocation}")
    
    # Start finding at position 5 because "s3://" is 5 characters long
    file_path_in_bucket = OutputLocation[OutputLocation.find("/",5)+1:]
    logger.info(f"file_path_in_bucket is: {file_path_in_bucket}")

    OutputLocation_temp = OutputLocation[OutputLocation.find("/",4)+1:]
    loc = OutputLocation_temp.find("/")
    bucket_name = OutputLocation_temp[:loc]
    logger.info(f"The bucket name is: {bucket_name}")

    read_query_csv(bucket_name, file_path_in_bucket)
    
    logger.info("Lambda Function ended.")