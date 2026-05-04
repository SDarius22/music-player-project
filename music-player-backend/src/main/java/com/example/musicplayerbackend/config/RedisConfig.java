package com.example.musicplayerbackend.config;

import com.example.musicplayerbackend.components.RedisSignalingListener;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;
import org.springframework.data.redis.listener.adapter.MessageListenerAdapter;
import org.springframework.data.redis.serializer.StringRedisSerializer;

@Configuration
public class RedisConfig {

    @Bean
    public RedisTemplate<String, String> redisTemplate(RedisConnectionFactory factory) {
        RedisTemplate<String, String> template = new RedisTemplate<>();
        template.setConnectionFactory(factory);
        StringRedisSerializer str = new StringRedisSerializer();
        template.setKeySerializer(str);
        template.setValueSerializer(str);
        template.setHashKeySerializer(str);
        template.setHashValueSerializer(str);
        template.afterPropertiesSet();
        return template;
    }

    @Bean
    public MessageListenerAdapter syncMessageListenerAdapter(RedisSignalingListener listener) {
        MessageListenerAdapter adapter = new MessageListenerAdapter(listener, "onSyncTrigger");
        adapter.setSerializer(new StringRedisSerializer());
        adapter.afterPropertiesSet();
        return adapter;
    }

    @Bean
    public MessageListenerAdapter webrtcMessageListenerAdapter(RedisSignalingListener listener) {
        MessageListenerAdapter adapter = new MessageListenerAdapter(listener, "onWebRTCSignal");
        adapter.setSerializer(new StringRedisSerializer());
        adapter.afterPropertiesSet();
        return adapter;
    }

    @Bean
    public RedisMessageListenerContainer redisMessageListenerContainer(
            RedisConnectionFactory factory,
            MessageListenerAdapter syncMessageListenerAdapter,
            MessageListenerAdapter webrtcMessageListenerAdapter) {

        RedisMessageListenerContainer container = new RedisMessageListenerContainer();
        container.setConnectionFactory(factory);
        container.addMessageListener(syncMessageListenerAdapter, new ChannelTopic("signaling:sync"));
        container.addMessageListener(webrtcMessageListenerAdapter, new ChannelTopic("signaling:webrtc"));
        return container;
    }
}
