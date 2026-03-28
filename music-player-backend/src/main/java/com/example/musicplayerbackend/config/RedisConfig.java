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
        return template;
    }

    @Bean
    public RedisMessageListenerContainer redisMessageListenerContainer(
            RedisConnectionFactory factory,
            RedisSignalingListener listener) {
        StringRedisSerializer str = new StringRedisSerializer();

        MessageListenerAdapter syncAdapter = new MessageListenerAdapter(listener, "onSyncTrigger");
        syncAdapter.setSerializer(str);

        MessageListenerAdapter playbackAdapter = new MessageListenerAdapter(listener, "onPlaybackStateChanged");
        playbackAdapter.setSerializer(str);

        RedisMessageListenerContainer container = new RedisMessageListenerContainer();
        container.setConnectionFactory(factory);
        container.addMessageListener(syncAdapter, new ChannelTopic("signaling:sync"));
        container.addMessageListener(playbackAdapter, new ChannelTopic("signaling:playback"));
        return container;
    }
}