-----------------------------------------------
-- Remote Call
-- self.gameObject.networkSync:RemoteCall( "GlobalFunctionNameToCallOnTheServer", function( dataFromTheServer )  end )

NetworkSync.RemoteCall = {
    id = 0,
    callbacksById = {}
} 


-- @param networkSync (NetworkSync)
-- @param functionName (string) The name of the global function (may be nested in tables) to call on the server.
-- @param callback (function) [optional] The function called with the data from the server
function NetworkSync.RemoteCall( networkSync, functionName, remoteCallback )
    cprint("NetworkSync.RemoteCall", functionName )
    local id = NetworkSync.RemoteCall.id
    NetworkSync.RemoteCall.id = id + 1
    NetworkSync.RemoteCall.callbacksById[ id ] = remoteCallback
    networkSync:SendMessageToServer( "RemoteCallServer", { functionName = functionName, callbackId = id } )
end


function Behavior:RemoteCallServer( data, playerId )
    cprint("RemoteCallServer()")
    local f = table.getvalue( _G, data.functionName )
    local newData = f()
    
    if newData == nil then
        newData = {}
    end
    if type( newData ) ~= "table" then
        newData = { singleValue = newData }
    end
    newData.callbackId = data.callbackId
    
    self.gameObject.networkSync:SendMessageToPlayers( "RemoteCallClient", newData, { playerId } )
end
CS.Network.RegisterMessageHandler( Behavior.RemoteCallServer, CS.Network.MessageSide.Server )


function Behavior:RemoteCallClient( data )
    cprint("Behavior:RemoteCallClient()")
    
    local id = data.callbackId
    data.callbackId = nil
    if id ~= nil then
        local f = NetworkSync.RemoteCall.callbacksById[ id ]
        if f ~= nil then
            if data.singleValue ~= nil then
                data = data.singleValue
            end
            f( data )
        end
    end
end
CS.Network.RegisterMessageHandler( Behavior.RemoteCallClient, CS.Network.MessageSide.Players )