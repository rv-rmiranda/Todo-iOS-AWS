# Todo-iOS-AWS

Wondering how to take a modern approach to building an API? In this post, we’ll be using AWS services Appsync and Amplify, to create and test a GraphQL API for an iOS application. The post is divided into the following sections including images and logs:

- Creating GraphQL Schema
- Configuring AWS Amplify
- Initializing Amplify
- Creating the API
- API Local Mocking/Test
- Deploying API into AWS
- Cleaning AWS Account
- Integrating API with iOS Application

Before you get started, make sure you have the following:
1. AWS Account
2. Software/Tools:
    - AWS CLI
    - Node JS
    - AWS Amplify
    - Docker
    - Java 8
3. For the API integration:
    - macOS Mojave or later
    - Xcode 10.3 or later
    - CocoaPods 
    - Clone the iOS project from GitHub
    
    ## Creating GraphQL Schema
The GraphQL Transform provides a simple to use abstraction that helps you quickly create backends for your web and mobile applications on AWS. With the GraphQL Transform, you define your application’s data model using the GraphQL Schema Definition Language (SDL).

For example, we can create the Backend of our Todo app with the following schema:
``` 
type User @model @auth(rules: [{ allow: owner, ownerField: "id", operations: [create, update, delete]}])
{
    id: ID!
    username: String!
    lists: [List] @connection(name: "UserList", keyField: "authorId")
    createdAt: String
    updatedAt: String
}

type List @model @auth(rules: [{allow: owner, ownerField: "authorId", operations: [create, update, delete]}])@key(name: "byAuthor", fields: ["authorId", "createdAt"], queryField: "getUserLists")
{
    id: ID!
    authorId: ID
    author: User! @connection(name: "UserList", keyField: "authorId")
    title: String!
    colorHex: String!
    items: [Item] @connection(name: "ListItems", keyField: "listId")
    createdAt: String
    updatedAt: String
}
type Item @model @auth(rules: [{allow: owner, operations: [create, update, delete]}])
@key(name: "byList", fields: ["listId", "createdAt"], queryField: "getListsItems")
{
    id: ID!
    listId: ID!
    list: List @connection(name: "ListItems", keyField: "listId")
    title: String!
    search_title: String!
    done: Boolean!
    createdAt: String
    updatedAt: String
}
```
    
In the above schema, we can see some annotations with ‘@’; these are called Directives. Here are some common annotations that are also used in the example:
        - @model — Objects annotated with @model are stored in Amazon DynamoDB and will deploy DynamoDB tables, resolvers, and additional GraphQL schemas.
        - @auth — Allows the definition of auth rules and builds the corresponding GraphQL resolvers based on these rules.
        - @connection — Enables you to specify relationships between `@model` object types
        - @key — Enables you to configure custom index structures for @model types
        
In the next sessions, we will see with more details how AppSync uses these Directives annotations to create the API infrastructure.
    
## Configuring AWS Amplify
Amplify is a CLI tool developed by AWS to create, integrate, and manage the AWS infrastructure. To install Amplify you will need at least Node.js version 8.12 or greater and NPM version 5.x or greater. Open a terminal window and run the following commands:
```
$ npm install -g @aws-amplify/cli 
$ amplify configure
? region:  us-east-1  "Select the best region for you"
? user name: "Create a User in the AWS Console"
Enter the access key of the newly created user:
? accessKeyId:  <YOUR_ACCE**********
? secretAccessKey:  <YOUR_SECRET************
Initializing Amplify
```
        
The “init” command must be executed at the root directory of a project to initialize the project for the Amplify CLI to work with.
```
$ amplify init
? Enter a name for the project Todo  "Can be any name"
? Enter a name for the environment dev "e.g. dev, stage, prod"
? Choose your default editor: Visual Studio Code "Select the one
you like"
? Choose the type of app that you're building ios
? Do you want to use an AWS profile? (Y/n)
- If you do not have a profile, put "n" and press enter:
? accessKeyId:  <YOUR_ACCE**********
? secretAccessKey:  <YOUR_SECRET************
? region:  us-east-1
- Otherwise, put "y", press enter and select and excisting
profile. 
```
    
## Creating the API
    
Now that Amplify is configured and initialized, we will use the GraphQL schema with the command below to enables AppSync GraphQL API in your project. 
    
First, let’s add authentication by executing the command:
```
$ amplify add auth
? Do you want to use the default authentication and security configuration? Default configuration
How do you want users to be able to sign in? Username
Do you want to configure advanced settings? No, I am done.
```
Second, let’s add the API by executing the command:
```
$ amplify add api
? Please select from one of the below mentioned services
(Use arrow keys) GraphQL
? Provide API name: Todo
? Choose an authorization type for the API Amazon Cognito User
Pool
? Do you have an annotated GraphQL schema? Yes
? Provide your schema file path: ./todo-schema.graphql
GraphQL schema compiled successfully.
Edit your schema at ./amplify/backend/api/todo/schema.graphql or 
place .graphql files in a directory at 
./amplify/backend/api/todo/schema
Successfully added resource todo locally
```
    
It is very important that you understand what we just did in the previous step. We are using the GraphQL schema to define the structure of our API. By providing the schema in ./todo-schema.graphql, these will do the following:
    - In our schema, we are using the directive annotation “@auth”, this means that we need an authentication mechanism for our API. Since we are in AWS, Amazon Cognito lets you add user sign-up, sign-in, and access control to your web and mobile apps. This will tell AppSync to create an Amazon Cognito User Pool, that will allow us the create users for our application and add authentication to the Queries, Mutations, etc.
   -  When we added “@model” this is telling AppSync to create a DynamoDB table, in this case, tree tables Users, Lists and Items, and also IAM roles and up to 8 resolvers(create, update, delete, get, list, onCreate, onUpdate, onDelete) per table.
    - By using the directive annotation “@key”, this will create secondary indexes in our tables that will allow us to have custom queries that do not require the primary index key.
    
Note: We will be deploying the API into AWS in the next sessions.
    
## API Local Mocking/Test
To test out the API we can do something called Mocking. In this case, we will be using a Docker container to test AWS DynamoDB on our computer. For this, we need Docker installed on our computers. To download the Docker images amazon/dynamodb-local execute:
```$ docker pull amazon/dynamodb-local```
Wait until the docker image is downloaded. To start the mocking/simulation of our API, execute the following command:
```
$ amplify mock api

Creating table UserTable locally
Creating table ListTable locally
Creating table ItemTable locally
Running GraphQL codegen
? Enter the file name pattern of graphql queries, mutations and  
subscriptions (graphql/**/*.graphql) "Press Enter/return"
? Do you want to generate/update all possible GraphQL operations - 
queries, mutations and subscriptions (Y/n) Y
? Enter maximum statement depth [increase from default if your 
schema is deeply nested] (2) 2
? Enter the file name for the generated code (API.swift) 
"Press Enter/return"
? Do you want to generate code for your newly created GraphQL API 
Y
✔ Generated GraphQL operations successfully and saved at graphql
✔ Code generated successfully and saved in file API.swift
AppSync Mock endpoint is running at http://10.150.141.39:20002
```
Now copy the endpoint/URL (e.g. http://10.150.141.39:20002) into your browser (e.g. Chrome, Safari, Firefox, etc.), you should now have something similar to the screenshot below.
    
Note: You will notice that in the project directory the files “API.swift”, “awsconfiguration.json” and folder “graphql” were created. We will talk about these files in Part II.
    
1. Authentication — Since we specified that we are using Amazon Cognito User Pool, we can create different users to test the authentication. To change the users, look in the top menu and press “Auth” and change the user info.
    
2. Mutations — In the left menu select “+ Add New Mutations”. Now you will see a list of mutations (Create, Update, Delete) per table. Now select “createList”, fill the require data and press the “Play” button.
    
3. Query — In the left menu select “+ Add New Query”. Now you will see a list of queries (Get and List) per table and the custom queries listUserLists and listListsItems that were created by specifying the directive annotation “@key”. Now select “getList”, copy the “id” of the new list, fill the require data and press the “Play” button.
    
4. Test Authentication — In the first step, we created the user “UresTest” and we created a list with that user. In the schema we added the line:
```@auth(rules: [{allow: owner, operations: [create, update, delete]}])```
This means that the owner of the record is the only one that can update and delete it. To test this, let’s create a new user “UserTest2” and using the mutation deleteList let's try to delete the list. If the authentication work as expected we will get the following error:
```
{
    "data": {
        "__typename": "Mutation",
        "deleteList": null
    },
    "errors": [
        {
            "message": "The conditional request failed",
            "locations": [
                {
                    "line": 3,
                    "column": 3
                }
        ],
        "path": [
            "deleteList"
        ],
        "errorType": "DynamoDB:ConditionalCheckFailedException"
        }
    ]
}
```
        
For more details about the logic that is happening in the background, we can go into the terminal window were the mocking was started and see the log of the execution:
```
Error while executing Local DynamoDB
{
    "version": "2017-02-28",
    "operation": "DeleteItem",
    "key": {
        "id": {
            "S": "94cfb64b-2bc1-4b34-866d-6cb23f0ac467"
        }
    },
    "condition": {
        "expression": "( #owner0 = :identity0) AND attribute_exists(#id)",
        "expressionNames": {
            "#owner0": "owner",
            "#id": "id"
        },
        "expressionValues": {
            ":identity0": {
                "S": "UsetTest2"
            }
        }
    }
}
ConditionalCheckFailedException: The conditional request failed
```
            
## Deploy API into AWS

Now that we have tested our the API, it is time to deploy it into AWS. To do the deployment lets execute the following command:
``` 
$ amplify push
Current Environment: dev
| Category  | Resource name | Operation | Provider plugin   |
| --------- | ------------- | --------- | ----------------- |
| Api       | Todo          | Create    | awscloudformation |
| Auth      | todo          | Create    | awscloudformation |
? Are you sure you want to continue? (Y/n) Y 
```
    
This may take a couple of minutes. Once the execution finished, we can go into the AWS console into AppSync to see the resources that were created and how they are integrated with our API.
* API — When we go into AppSync we can see that our API was created with the name “Todo-dev”, this is basically the name and environment we provided in the configuration.
    
* Data Sources — Here we can see the DynamoDB tables that were created or are part of the API. Also, in the resource column we can see that the actual name of the tables are “type-api-id-environment”.
    
* Authorization — In the settings of the API, we can see that the default authorization is “Amazon Cognito User Pool” and the user pool that was created.
    
## Clean AWS Account
AWS will charge you for the resources amplify has created in your account. To remove the resources amplify has created, execute the following command:
```$ amplify delete```
    
Hopefully, this helped you create and understand the basics of how to create an API using AWS resources. Soon I will be publishing “[“AWS [Amplify, Appsync, GraphQL] — Integrating an API in iOS {Part II}](http://www.dropwizard.io/1.0.2/docs/)”. Please, leave you comments below and follow me for future posts.
