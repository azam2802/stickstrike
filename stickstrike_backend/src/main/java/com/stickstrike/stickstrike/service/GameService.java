package com.stickstrike.stickstrike.service;

import com.stickstrike.stickstrike.model.*;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class GameService {
    private final Map<String, Player> players = new ConcurrentHashMap<>();
    private static final float BASE_DAMAGE = 10.0f;

    public GameState addPlayer(String playerId, String playerName) {
        Player player = new Player(playerId, playerName);
        players.put(playerId, player);
        return new GameState(players);
    }

    public GameState updatePlayerPosition(String playerId, Vector2 position, Vector2 velocity) {
        Player player = players.get(playerId);
        if (player != null) {
            player.setPosition(position);
            player.setVelocity(velocity);
        }
        return new GameState(players);
    }

    public GameState processHit(String attackerId, String targetId, Vector2 hitPoint) {
        Player attacker = players.get(attackerId);
        Player target = players.get(targetId);

        if (attacker != null && target != null) {
            HitBoxPart hitPart = target.getHitBox().getHitPart(hitPoint);
            float damage = BASE_DAMAGE * hitPart.getDamageMultiplier();

            target.setHealth(Math.max(0, target.getHealth() - (int) damage));

            // Если игрок умер, удаляем его
            if (target.getHealth() <= 0) {
                players.remove(targetId);
            }
        }

        return new GameState(players);
    }
}