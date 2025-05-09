package com.stickstrike.stickstrike.model;

import java.util.Map;

public class GameState {
    private Map<String, Player> players;

    public GameState(Map<String, Player> players) {
        this.players = players;
    }

    public Map<String, Player> getPlayers() {
        return players;
    }

    public void setPlayers(Map<String, Player> players) {
        this.players = players;
    }
}