
// Load the SDK for JavaScript
const AWS = require('aws-sdk');
const fetch = require('node-fetch');
const logger = require('pino')({ name: 'Get Event Details', level: 'info' });
// Set the region
AWS.config.update({ region: process.env.region });

// Create DynamoDB document client
const docClient = new AWS.DynamoDB.DocumentClient({ apiVersion: '2012-08-10' });

const TABLE_NAME = process.env.table;

async function fetchDetails(url, auth) {
  const results = await fetch(
    url,
    {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        Authorization: auth
      },
    },
  );
  const resultsJson = await results.json();
  return resultsJson;
}

exports.handler = async (event) => {
  try {
    logger.info(event);
    const { params } = event;
    const { header } = params;

    const { eventId } = params.path;

    const getItemParams = {
      TableName: TABLE_NAME,
      Key: {
        eventId,
      },
      ConditionExpression: 'attribute_exists(eventId)',
    };

    logger.info('Get Item Params:');
    logger.info(getItemParams);

    // get item
    const response = await docClient.get(getItemParams).promise();

    if (response.errorMessage) {
      throw new Error(response.errorMessage);
    } else if (!response.Item) {
      throw new Error('Item not found');
    }
    
    const applications = await fetchDetails(`https://nzaz46iujc.execute-api.eu-west-1.amazonaws.com/dev/applications?eventId=${response.Item.eventId}`, header.Authorization);
    response.Item.applications = applications.Items;

    logger.info(response);

    return response;
  } catch (err) {
    logger.info(err);
    return err;
  }
};
