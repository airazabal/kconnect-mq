#FROM  ibmcom/eventstreams-kafka-ce-icp-linux-amd64:2019.4.1-095ae1e as builder
FROM ibmjava:8-jre as builder

COPY . .
RUN cat settings.xml
RUN ./mvnw package -s ./settings.xml

FROM strimzi/kafka:latest-kafka-2.5.0

COPY --from=builder connectors/* /opt/connectors/
COPY --from=builder config/connect-distributed.properties /opt/kafka/config/

USER root

RUN usermod -a -G root kafka && \
  chgrp 0 -R /opt && \
  chmod g+rwx -R /opt

USER kafka
# RUN addgroup --gid 5000 --system esgroup && \
#     adduser --uid 5000 --ingroup esgroup --system esuser

# COPY --chown=esuser:esgroup --from=builder /opt/kafka/bin/ /opt/kafka/bin/
# COPY --chown=esuser:esgroup --from=builder /opt/kafka/libs/ /opt/kafka/libs/
# COPY --chown=esuser:esgroup --from=builder /opt/kafka/config/connect-distributed.properties /opt/kafka/config/
# COPY --chown=esuser:esgroup --from=builder /opt/kafka/config/connect-log4j.properties /opt/kafka/config/
# RUN mkdir /opt/kafka/logs && chown esuser:esgroup /opt/kafka/logs

# RUN mkdir /opt/connectors && chown esuser:esgroup /opt/connectors
# COPY --chown=esuser:esgroup config/ /opt/kafka/config
# #COPY --chown=esuser:esgroup certs/es-cert.jks /opt/kafka/es-cert.jks
# #COPY --chown=esuser:esgroup certs/registry-es-cert.jks /opt/kafka/registry-es-cert.jks 
# COPY --chown=esuser:esgroup connectors /opt/connectors/
# COPY --chown=esuser:esgroup es-cert.jks /opt/kafka/

WORKDIR /opt/kafka

EXPOSE 8083

ENTRYPOINT ["./bin/connect-distributed.sh", "config/connect-distributed.properties"]
