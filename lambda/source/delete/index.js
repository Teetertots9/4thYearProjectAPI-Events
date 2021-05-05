
// Load the SDK for JavaScript
const AWS = require('aws-sdk');
const logger = require('pino')({ name: 'Create Application', level: 'info' });
// Set the region
AWS.config.update({ region: process.env.region });

// Create DynamoDB document client
const docClient = new AWS.DynamoDB.DocumentClient({ apiVersion: '2012-08-10' });

const TABLE_NAME = process.env.table;

exports.handler = async (event) => {
  try {
    logger.info(event);
    const { params } = event;

    const { eventId } = params.path;

    const deleteItemParams = {
      TableName: TABLE_NAME,
      Key: {
        eventId,
      },
      ConditionExpression: 'attribute_exists(eventId)',
    };

    logger.info('Delete Item Params:');
    logger.info(deleteItemParams);

    // delete item
    const response = await docClient.delete(deleteItemParams).promise();

    if (response.errorMessage) {
      throw new Error(response.errorMessage);
    }

    response.eventId = eventId;
    response.Message = 'Item Deleted Succesfully';

    logger.info(response);

    return response;
  } catch (err) {
    logger.info(err);
    return err;
  }
};
