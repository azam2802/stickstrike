package com.stickstrike.stickstrike.model;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class Room {
    private String id;
    private String name;
    private Map<String, Player> players;
    private int maxPlayers;
    private boolean started;

    public Room(String name) {
        this.id = UUID.randomUUID().toString();
        this.name = name;
        this.players = new HashMap<>();
        this.maxPlayers = 2;
        this.started = false;
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public Map<String, Player> getPlayers() {
        return players;
    }

    public int getPlayerCount() {
        return players.size();
    }

    public int getMaxPlayers() {
        return maxPlayers;
    }

    public void setMaxPlayers(int maxPlayers) {
        this.maxPlayers = maxPlayers;
    }

    public boolean isFull() {
        return players.size() >= maxPlayers;
    }

    public boolean isStarted() {
        return started;
    }

    public void setStarted(boolean started) {
        this.started = started;
    }

    public boolean addPlayer(Player player) {
        if (isFull() || isStarted()) {
            return false;
        }
        players.put(player.getId(), player);
        return true;
    }

    public boolean removePlayer(String playerId) {
        return players.remove(playerId) != null;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> result = new HashMap<>();
        result.put("id", id);
        result.put("name", name);
        result.put("playerCount", players.size());
        result.put("maxPlayers", maxPlayers);
        result.put("started", started);
        return result;
    }
}