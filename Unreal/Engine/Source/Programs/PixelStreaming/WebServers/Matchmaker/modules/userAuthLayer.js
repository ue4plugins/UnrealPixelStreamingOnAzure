const { TableClient, odata } = require('@azure/data-tables');
const bcrypt = require('bcryptjs');

const partitionKey = 'user';
const saltRounds = 10;
const tableName = 'users';
let storageClient;

function Initialize(connectionString) {
  storageClient = TableClient.fromConnectionString(connectionString, tableName);
}

async function ListUsers() {
  try {
    const listResults = storageClient.listEntities({
      queryOptions: {
        filter: odata`PartitionKey eq ${partitionKey}`,
      },
    });

    const users = [];
    const iterator = listResults.byPage({ maxPageSize: 100 });
    for await (const page of iterator) {
      users.push.apply(users, page);
    }

    return users;
  } catch (error) {
    console.log(error);
  }
}

async function GetUser(username) {
  try {
    const entity = await storageClient.getEntity(partitionKey, username);
    return entity;
  } catch (error) {
    console.log(error);
  }
}

async function WriteUser(username, password) {
  try {
    const passwordHash = await bcrypt.hash(password, saltRounds);
    const entity = {
      partitionKey: partitionKey,
      rowKey: username,
      username,
      passwordHash,
    };

    await storageClient.createEntity(entity);

    return { username };
  } catch (error) {
    console.log(error);
  }
}

async function UpdateUser(username, password) {
  try {
    const passwordHash = await bcrypt.hash(password, saltRounds);
    const entity = {
      partitionKey: partitionKey,
      rowKey: username,
      username,
      passwordHash,
    };

    await storageClient.updateEntity(entity, 'Replace');

    return { username };
  } catch (error) {
    console.log(error);
  }
}

async function DeleteUser(username) {
  try {
    await storageClient.deleteEntity(partitionKey, username);

    return { username };
  } catch (error) {
    console.log(error);
  }
}

module.exports = {
  init: Initialize,
  ListUsers,
  GetUser,
  WriteUser,
  UpdateUser,
  DeleteUser,
};
