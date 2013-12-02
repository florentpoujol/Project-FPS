--[[
<?php

function _log( $text ) {
    $text = date_format( date_create(), 'Y-m-d H:i:s' )." : ".$text."\n";
    file_put_contents( "log.txt", $text, FILE_APPEND );
}

$handle = opendir("."); // current dir
$serversById = array();
$response = "{}";
$get_response = "";
$query_type = "GET";

while (false !== ($entry = readdir($handle))) {
    if (substr($entry, -5) == ".json") {
        $id = str_replace("server", "", $entry);
        $id = str_replace(".json",  "", $id);
        $id = intval( $id );
        $server = file_get_contents( $entry );
        $serversById[ $id ] = $server;

        $get_response .= $id.": ".$serversById[$id].",";
    }
}
closedir($handle);

if (!empty($_POST)) {
    $query_type = "POST";
    $server = $_POST;

    if ( isset( $server["deleteFromServerBrowser"] ) && $server["deleteFromServerBrowser"] == "true" ) {
        $id = $server["id"];
        if ($id > 0) {
            _log( "Delete server with id ".$id );
            unlink("server".$id.".json");
            $response = '{"deleteFromServerBrowser":true}';
        }
    }
    else {
        if ( isset( $server["id"] ) && $server["id"] >= 1 ) // update server
            $id = intval( $server["id"] );
        else { // new server
            // get the lowest available id
            for ($i=1; $i < 99999999; $i++) { 
                if (!array_key_exists( $i, $serversById ) ) {
                    $id = $i;
                    $server["id"] = $id;
                    break;
                }
            }
        }

        $server["ip"] = $_SERVER['REMOTE_ADDR'];
        if ($server["ip"] == "::1")
            $server["ip"] = "127.0.0.1";

        // check if another server already has this IP
        // in order to reuse the id and file
        foreach ($serversById as $id => $str_server) {
            $_server = json_decode( $str_server, true );            
            if ($_server["ip"] == $server["ip"]) {
                $server = array_merge( $_server, $server );
                $server["id"] = $id;
                break;
            }
        }

        $str_server = json_encode( $server );
        _log( "Write server : ".$str_server );
        file_put_contents( "server".$server["id"].".json", $str_server );
        $response = '{"id":'.$server["id"].', "ip":"'.$server["ip"].'"}';
    }

} else { // assume GET
    $response = substr($get_response, 0, strlen($get_response)-1); // removes the last coma
    $response = "{".$response."}";
}

if (trim($response) == "") 
    $response = "{}";

_log( $query_type." : Response : ".$response );
echo $response;
]]