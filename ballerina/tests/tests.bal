import ballerina/http;
import ballerina/io;
import ballerina/oauth2;
import ballerina/test;

configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string refreshToken = ?;
configurable string serviceUrl = ?;

OAuth2RefreshTokenGrantConfig auth = {
    clientId: clientId,
    clientSecret: clientSecret,
    refreshToken: refreshToken,
    credentialBearer: oauth2:POST_BODY_BEARER
};

ConnectionConfig config = {auth: auth};
final Client hubspot = check new Client(config, serviceUrl);
# keep the deal id as reference for other tests after creation
string dealId = "";

string batchDealId1 = "";
string batchDealId2 = "";

@test:Config
function testCreateDeals() returns error? {

    SimplePublicObjectInputForCreate payload = {
        properties: {
            "pipeline": "default",
            "dealname": "Test Deal",
            "amount": "100000"
        }
    };

    SimplePublicObject|error out = hubspot->/.post(payload = payload);

    if out is SimplePublicObject {
        dealId = out.id;
        test:assertTrue(out.createdAt !is "");
    } else {
        test:assertFail("Failed to create deal");
    }

};

@test:Config {
    dependsOn: [testCreateDeals]
}
function testgetAllDeals() returns error? {
    CollectionResponseSimplePublicObjectWithAssociationsForwardPaging|error deals = hubspot->/;

    if deals is CollectionResponseSimplePublicObjectWithAssociationsForwardPaging {
        test:assertTrue(deals.results.length() > 0);
    } else {
        test:assertFail("Failed to get deals");
    }

};

@test:Config {
    dependsOn: [testgetAllDeals]
}
function testGetDealById() returns error? {
    SimplePublicObject|error deal = hubspot->/[dealId].get();
    if deal is SimplePublicObject {
        io:println(deal);
        test:assertTrue(deal.id == dealId);
    } else {
        test:assertFail("Failed to get deal");
    }
};

@test:Config {
    dependsOn: [testGetDealById]
}
function testUpdateDeal() returns error? {
    SimplePublicObjectInput payload = {
        properties: {
            "dealname": "Test Deal Updated",
            "amount": "200000"
        }
    };

    SimplePublicObject|error out = hubspot->/[dealId].patch(payload = payload);

    if out is SimplePublicObject {
        test:assertTrue(out.updatedAt !is "");
        test:assertEquals(out.properties["dealname"], "Test Deal Updated");
        test:assertEquals(out.properties["amount"], "200000");
    } else {
        test:assertFail("Failed to update deal");
    }
};

@test:Config {
    dependsOn: [testUpdateDeal]
}
function testMergeDeals() returns error? {

    string dealId2 = "";
    SimplePublicObjectInputForCreate payload = {
        properties: {
            "pipeline": "default",
            "dealname": "Test Deal2",
            "amount": "300000"
        }
    };

    SimplePublicObject|error out = hubspot->/.post(payload = payload);

    if out is SimplePublicObject {
        dealId2 = out.id;
        PublicMergeInput payload2 = {
            objectIdToMerge: dealId2,
            primaryObjectId: dealId
        };
        SimplePublicObject|error mergeOut = hubspot->/merge.post(payload = payload2);
        if mergeOut is SimplePublicObject {
            test:assertNotEquals(mergeOut.properties["hs_merged_object_ids"], "");
            dealId = mergeOut.id;
        } else {
            test:assertFail("Failed to create the secondary deal");
        }
    } else {
        test:assertFail("Failed to merge deals");
    }

};

@test:Config {
    dependsOn: [testUpdateDeal]
}
function testSearchDeals() returns error? {
    PublicObjectSearchRequest qr = {
        query: "test"
    };
    CollectionResponseWithTotalSimplePublicObjectForwardPaging|error search = hubspot->/search.post(payload = qr);
    if search is CollectionResponseWithTotalSimplePublicObjectForwardPaging {
        test:assertTrue(search.results.length() > 0);
    } else {
        test:assertFail("Failed to search deals");
    }
};

@test:Config {
    dependsOn: [testSearchDeals]
}
function testDeleteDeal() returns error? {
    var response = hubspot->/[dealId].delete();
    if
        response is http:Response {
        test:assertTrue(response.statusCode == 204);
    } else {
        test:assertFail("Failed to delete deal");
    }
}

@test:Config {
    dependsOn: [testDeleteDeal]
}
function testBatchCreate() returns error? {
    SimplePublicObjectInputForCreate payload1 = {
        properties: {
            "pipeline": "default",
            "dealname": "Test Deal1",
            "amount": "100000"
        }
    };
    SimplePublicObjectInputForCreate payload2 = {
        properties: {
            "pipeline": "default",
            "dealname": "Test Deal2",
            "amount": "200000"
        }
    };
    BatchInputSimplePublicObjectInputForCreate payloads = {
        inputs: [payload1, payload2]
    };
    BatchResponseSimplePublicObject|BatchResponseSimplePublicObjectWithErrors|error out = hubspot->/batch/create.post(payload = payloads);

    if out is BatchResponseSimplePublicObject {
        test:assertTrue(out.results.length() == 2);
        batchDealId1 = out.results[0].id;
        batchDealId2 = out.results[1].id;
    } else {
        test:assertFail("Failed to batch create deals");
    }

}

@test:Config {
    dependsOn: [testBatchCreate]
}
function testBacthUpdate() returns error? {
    SimplePublicObjectBatchInput payload1 = {
        id: batchDealId1,
        properties: {
            "dealname": "Test Deal1 Updated",
            "amount": "300000",
            "test": "testID1"

        }
    };
    SimplePublicObjectBatchInput payload2 = {
        id: batchDealId2,
        properties: {
            "dealname": "Test Deal2 Updated",
            "amount": "400000"
        }
    };
    BatchInputSimplePublicObjectBatchInput payloads = {
        inputs: [payload1, payload2]
    };
    BatchResponseSimplePublicObject|BatchResponseSimplePublicObjectWithErrors|error out = hubspot->/batch/update.post(payload = payloads);

    if out is BatchResponseSimplePublicObject {

        test:assertTrue(out.results.length() == 2);
        SimplePublicObject updatedDeal1 = out.results.filter(function(SimplePublicObject deal) returns boolean {
            return deal.id == batchDealId1;
        })[0];
        test:assertEquals(updatedDeal1.properties["dealname"], "Test Deal1 Updated");
    } else {
        test:assertFail("Failed to batch update deals");
    }

}

//for the this test case you should create a custom unique property for the deals 
//my property comes as `test`
//ref:https://www.youtube.com/watch?v=3p6deGTS12w, 
@test:Config {
    dependsOn: [testBacthUpdate]
}
function testBatchUpsert() returns error? {
    SimplePublicObjectBatchInputUpsert payload1 = {
        id: "testID1",
        idProperty: "test",
        properties: {
            "pipeline": "default",
            "dealname": "Test Deal1",
            "amount": "1034500"
        }
    };
    BatchInputSimplePublicObjectBatchInputUpsert payloads = {
        inputs: [payload1]
    };
    BatchResponseSimplePublicUpsertObject|BatchResponseSimplePublicUpsertObjectWithErrors|error out = hubspot->/batch/upsert.post(payload = payloads);
    io:println(out);
    if out is BatchResponseSimplePublicUpsertObject {
        test:assertTrue(out.results.length() == 1);
    } else {
        test:assertFail("Failed to batch upsert deals");
    }

}

@test:Config {
    dependsOn: [testBatchUpsert]
}
function testBatchInputDelete() returns error? {
    SimplePublicObjectId payload1 = {
        id: batchDealId1
    };

    SimplePublicObjectId payload2 = {
        id: batchDealId2
    };
    BatchInputSimplePublicObjectId payload = {
        inputs: [payload1, payload2]
    };
    http:Response|error out = hubspot->/batch/archive.post(payload = payload);

    if out is http:Response {
        test:assertTrue(out.statusCode == 204);
    } else {
        test:assertFail("Failed to batch delete deals");
    }

}

