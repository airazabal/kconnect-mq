set -x
curl -X DELETE  -w "%{http_code}" -H 'content-type: application/json' http://$1/connectors/jdbc-sink-connector
echo '\n'
curl -X POST  -w "%{http_code}" -H 'content-type: application/json' -d@"./config/jdbc-sink-connector.json" http://$1/connectors
echo '\n'
curl  -w "%{http_code}" -H 'content-type: application/json' http://$1/connectors
