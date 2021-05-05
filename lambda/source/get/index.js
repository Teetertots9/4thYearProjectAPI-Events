
// Load the SDK for JavaScript
const AWS = require('aws-sdk');
const fetch = require("node-fetch");
const logger = require('pino')({ name: 'Get Events', level: 'info' });
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
        Authorization: auth,
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

    const exclusiveStartKey = params.querystring.lastEvaluatedKey;
    const { artistSearchName } = params.querystring;
    const { venueSearchName } = params.querystring;
    const { artistId} = params.querystring;
    const { createdBy } = params.querystring;

    let filterString = '';
    const keyValueMapping = {};

    if (artistSearchName) {
      filterString += ' contains(artistSearchName, :artist) and ';
      keyValueMapping[':artist'] = decodeURIComponent(artistSearchName).toLowerCase();
    }
    if (venueSearchName) {
        filterString += ' contains(venueSearchName, :venue) and ';
      keyValueMapping[':venue'] = decodeURIComponent(venueSearchName).toLowerCase();
    }
    if (artistId) {
      filterString += ' contains(artistId, :artist) and ';
      keyValueMapping[':artist'] = artistId;
  }
  if (createdBy) {
    filterString += ' contains(createdBy, :create) and ';
    keyValueMapping[':create'] = createdBy;
  }

    filterString = filterString.slice(0, -4);

    const getAllParams = {
      TableName: TABLE_NAME,
    };

    if (exclusiveStartKey) {
      getAllParams.ExclusiveStartKey = {
        favoursId: exclusiveStartKey,
      };
    }

    if (filterString && filterString !== '') {
      getAllParams.FilterExpression = filterString;
    }

    if (Object.keys(keyValueMapping).length > 0) {
      getAllParams.ExpressionAttributeValues = keyValueMapping;
    }


    logger.info('Get All Params:');
    logger.info(getAllParams);

    let response = await docClient.scan(getAllParams).promise();

    if (response.errorMessage) {
      logger.error(response.errorMessage);
      throw new Error(response.errorMessage);
    }

    logger.info(response);
    for(var i = 0; i < response.Items.length; i++){
      let applications = await fetchDetails(`https://nzaz46iujc.execute-api.eu-west-1.amazonaws.com/dev/applications?eventId=${response.Items[i].eventId}`, header.Authorization);
      logger.info(applications)
      response.Items[i].applications = applications.Items;
    }

    return response;
  } catch (err) {
    logger.error(err);
    return err;
  }
};
