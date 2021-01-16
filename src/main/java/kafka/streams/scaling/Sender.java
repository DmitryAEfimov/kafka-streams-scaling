package kafka.streams.scaling;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Properties;
import java.util.UUID;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;
import org.apache.kafka.common.serialization.UUIDSerializer;
import org.apache.log4j.Logger;

public class Sender {
	private static final Logger log = Logger.getLogger(Sender.class);

	private KafkaProducer<UUID, String> producer;
	private String topicName;
	private String senderName;
	Map<UUID, List<String>> content;

	public Sender() {
		this.topicName = Optional.ofNullable(System.getenv("IN_TOPIC_NAME")).orElse("inScalingTopic");
		this.senderName = String.format("Sender-%s-%s", topicName, UUID.randomUUID().toString());
		initKafkaProducer();
		initChunks();
		log.info(String.format("Sender initialization complete: senderName=%s; chunkCount=%d; chunkSize=%d", senderName,
				content.size(), content.values().iterator().next().size()));
	}

	public static void main(String[] args) {
		Sender sender = new Sender();
		sender.doSend();

		log.info("Closing Kafka Producer");
		sender.producer.close();
	}

	private void initKafkaProducer() {
		Properties properties = new Properties();
		properties.put("bootstrap.servers",
				Optional.ofNullable(System.getenv("BOOTSTRAP_SERVERS_CONFIG")).orElse("localhost:9092"));
		properties.put("acks", "all");
		properties.put("retries", 0);
		properties.put("batch.size", 16384);
		properties.put("linger.ms", 1);
		properties.put("buffer.memory", 33554432);

		properties.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, UUIDSerializer.class);
		properties.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);

		log.info("Init Kafka Producer");
		this.producer = new KafkaProducer<>(properties);
	}

	private void initChunks() {
		int chunkCnt = Optional.ofNullable(System.getenv("SENDER_CHUNK_CNT")).map(Integer::parseInt).orElse(30);
		int chunkSize = Optional.ofNullable(System.getenv("SENDER_CHUNK_SIZE")).map(Integer::parseInt).orElse(10_000);

		this.content = new HashMap<>(chunkCnt);
		for (int i = 0; i < chunkCnt; i++) {
			List<String> messages = new ArrayList<>(chunkSize);
			for (int j = 0; j < chunkSize; j++) {
				messages.add("val" + j);
			}
			content.put(UUID.randomUUID(), messages);
		}
	}

	private void doSend() {
		log.info("Start");
		content.forEach((key, values) -> {
			values.forEach(message -> sendRecord(key, message));
			sendRecord(key, App.DONE);
		});
	}

	private void sendRecord(UUID key, String message) {
		ProducerRecord<UUID, String> record = new ProducerRecord<>(topicName, key, message);
		producer.send(record);
	}
}