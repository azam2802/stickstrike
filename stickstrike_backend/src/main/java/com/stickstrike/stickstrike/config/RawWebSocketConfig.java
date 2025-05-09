package com.stickstrike.stickstrike.config;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.stickstrike.stickstrike.model.HitBoxPart;
import com.stickstrike.stickstrike.model.Player;
import com.stickstrike.stickstrike.model.Room;
import com.stickstrike.stickstrike.model.Vector2;

@Configuration
@EnableWebSocket
public class RawWebSocketConfig implements WebSocketConfigurer {

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(gameWebSocketHandler(), "/rawws")
                .setAllowedOrigins("*");
    }

    @Bean
    public WebSocketHandler gameWebSocketHandler() {
        return new GameWebSocketHandler();
    }

    public static class GameWebSocketHandler extends TextWebSocketHandler {
        private final ConcurrentHashMap<String, WebSocketSession> sessions = new ConcurrentHashMap<>();
        private final ConcurrentHashMap<String, String> sessionToPlayerId = new ConcurrentHashMap<>();
        private final ConcurrentHashMap<String, Player> players = new ConcurrentHashMap<>();
        private final ConcurrentHashMap<String, Room> rooms = new ConcurrentHashMap<>();
        private final ObjectMapper objectMapper = new ObjectMapper();

        @Override
        public void afterConnectionEstablished(WebSocketSession session) throws Exception {
            String sessionId = session.getId();
            sessions.put(sessionId, session);
            System.out.println("WebSocket connection established: " + sessionId);

            // Generate player ID
            String playerId = UUID.randomUUID().toString();
            sessionToPlayerId.put(sessionId, playerId);

            // Create a player object immediately and add it to the players registry
            Player player = new Player(playerId, "Player " + playerId.substring(0, 4));
            players.put(playerId, player);
            System.out.println("Player created: " + playerId);

            // Send welcome message with player ID
            Map<String, Object> response = new HashMap<>();
            response.put("type", "connected");
            response.put("playerId", playerId);
            response.put("message", "Welcome to the game server!");

            sendMessage(session, response);
        }

        @Override
        protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
            String payload = message.getPayload();
            System.out.println("Received message: " + payload + " from session: " + session.getId());

            try {
                // Parse the message as JSON
                Map<String, Object> request = objectMapper.readValue(payload, Map.class);
                String type = (String) request.get("type");

                if (type == null) {
                    sendError(session, "Message type is required");
                    return;
                }

                // Handle different message types
                switch (type) {
                    case "get_rooms":
                        handleGetRooms(session);
                        break;
                    case "create_room":
                        handleCreateRoom(session, request);
                        break;
                    case "join_room":
                        handleJoinRoom(session, request);
                        break;
                    case "leave_room":
                        handleLeaveRoom(session);
                        break;
                    case "position":
                        handlePosition(session, request);
                        break;
                    case "hit":
                        handleHit(session, request);
                        break;
                    default:
                        sendError(session, "Unknown message type: " + type);
                }
            } catch (Exception e) {
                System.err.println("Error handling message: " + e.getMessage());
                sendError(session, "Error handling message: " + e.getMessage());
            }
        }

        private void handleGetRooms(WebSocketSession session) throws IOException {
            List<Map<String, Object>> roomList = new ArrayList<>();

            // Convert rooms to a list of maps
            for (Room room : rooms.values()) {
                if (!room.isStarted() && !room.isFull()) {
                    roomList.add(room.toMap());
                }
            }

            Map<String, Object> response = new HashMap<>();
            response.put("type", "room_list");
            response.put("rooms", roomList);

            sendMessage(session, response);
        }

        private void handleCreateRoom(WebSocketSession session, Map<String, Object> request) throws IOException {
            String roomName = (String) request.get("name");
            if (roomName == null || roomName.isEmpty()) {
                roomName = "Room " + (rooms.size() + 1);
            }

            // Get player ID associated with this session
            String sessionId = session.getId();
            String playerId = sessionToPlayerId.get(sessionId);

            // Create player if not exists
            if (!players.containsKey(playerId)) {
                String playerName = (String) request.get("playerName");
                if (playerName == null || playerName.isEmpty()) {
                    playerName = "Player " + playerId.substring(0, 4);
                }
                players.put(playerId, new Player(playerId, playerName));
            }

            // Create room
            Room room = new Room(roomName);
            Player player = players.get(playerId);
            room.addPlayer(player);
            rooms.put(room.getId(), room);

            // Send response
            Map<String, Object> response = new HashMap<>();
            response.put("type", "room_created");
            response.put("room", room.toMap());

            sendMessage(session, response);

            // Broadcast room list update to all connected clients
            broadcastRoomList();
        }

        private void handleJoinRoom(WebSocketSession session, Map<String, Object> request) throws IOException {
            String roomId = (String) request.get("roomId");
            if (roomId == null || roomId.isEmpty()) {
                sendError(session, "Room ID is required");
                return;
            }

            Room room = rooms.get(roomId);
            if (room == null) {
                sendError(session, "Room not found: " + roomId);
                return;
            }

            if (room.isFull()) {
                sendError(session, "Room is full");
                return;
            }

            if (room.isStarted()) {
                sendError(session, "Game has already started");
                return;
            }

            // Get player ID associated with this session
            String sessionId = session.getId();
            String playerId = sessionToPlayerId.get(sessionId);

            // Create player if not exists
            if (!players.containsKey(playerId)) {
                String playerName = (String) request.get("playerName");
                if (playerName == null || playerName.isEmpty()) {
                    playerName = "Player " + playerId.substring(0, 4);
                }
                players.put(playerId, new Player(playerId, playerName));
            }

            // Add player to room
            Player player = players.get(playerId);
            boolean added = room.addPlayer(player);

            if (!added) {
                sendError(session, "Failed to join room");
                return;
            }

            // Always send a room_joined response to the player who just joined
            Map<String, Object> roomJoinedMsg = new HashMap<>();
            roomJoinedMsg.put("type", "room_joined");
            roomJoinedMsg.put("room", room.toMap());

            // Add all players info
            Map<String, Object> playersInfo = new HashMap<>();
            for (Player roomPlayer : room.getPlayers().values()) {
                playersInfo.put(roomPlayer.getId(), roomPlayer);
            }
            roomJoinedMsg.put("players", playersInfo);

            sendMessage(session, roomJoinedMsg);

            // If room is full, start the game
            if (room.isFull()) {
                room.setStarted(true);

                // Notify all players in the room
                for (Player p : room.getPlayers().values()) {
                    for (Map.Entry<String, String> entry : sessionToPlayerId.entrySet()) {
                        if (entry.getValue().equals(p.getId())) {
                            WebSocketSession playerSession = sessions.get(entry.getKey());
                            if (playerSession != null && playerSession.isOpen()) {
                                Map<String, Object> gameStartedMsg = new HashMap<>();
                                gameStartedMsg.put("type", "game_started");
                                gameStartedMsg.put("room", room.toMap());

                                // Add all players info (same as in roomJoinedMsg)
                                gameStartedMsg.put("players", playersInfo);

                                sendMessage(playerSession, gameStartedMsg);
                            }
                        }
                    }
                }
            }

            // Broadcast room list update to all connected clients
            broadcastRoomList();
        }

        private void handleLeaveRoom(WebSocketSession session) throws IOException {
            // Get player ID associated with this session
            String sessionId = session.getId();
            String playerId = sessionToPlayerId.get(sessionId);

            // Find room containing this player
            Room playerRoom = null;
            for (Room room : rooms.values()) {
                if (room.getPlayers().containsKey(playerId)) {
                    playerRoom = room;
                    break;
                }
            }

            if (playerRoom == null) {
                sendError(session, "You are not in any room");
                return;
            }

            // Remove player from room
            playerRoom.removePlayer(playerId);

            // If room is empty, remove it
            if (playerRoom.getPlayerCount() == 0) {
                rooms.remove(playerRoom.getId());
            }

            // Send confirmation
            Map<String, Object> response = new HashMap<>();
            response.put("type", "room_left");

            sendMessage(session, response);

            // Broadcast room list update to all connected clients
            broadcastRoomList();
        }

        private void handlePosition(WebSocketSession session, Map<String, Object> request) throws IOException {
            // Get player ID associated with this session
            String sessionId = session.getId();
            String playerId = sessionToPlayerId.get(sessionId);

            if (playerId == null) {
                sendError(session, "Player not found");
                return;
            }

            // Get the player
            Player player = players.get(playerId);
            if (player == null) {
                sendError(session, "Player not found in registry");
                return;
            }

            // Update player position
            Map<String, Object> position = (Map<String, Object>) request.get("position");
            Map<String, Object> velocity = (Map<String, Object>) request.get("velocity");

            if (position != null) {
                double x = ((Number) position.get("x")).doubleValue();
                double y = ((Number) position.get("y")).doubleValue();
                player.getPosition().x = (float) x;
                player.getPosition().y = (float) y;
            }

            if (velocity != null) {
                double x = ((Number) velocity.get("x")).doubleValue();
                double y = ((Number) velocity.get("y")).doubleValue();
                player.getVelocity().x = (float) x;
                player.getVelocity().y = (float) y;
            }

            // Find which room the player is in
            Room playerRoom = null;
            for (Room room : rooms.values()) {
                if (room.getPlayers().containsKey(playerId)) {
                    playerRoom = room;
                    break;
                }
            }

            // Only broadcast if player is in a room
            if (playerRoom != null) {
                // Broadcast position update to all players in the room
                Map<String, Object> gameState = new HashMap<>();
                Map<String, Object> playersMap = new HashMap<>();

                for (Player p : playerRoom.getPlayers().values()) {
                    playersMap.put(p.getId(), p);
                }

                gameState.put("players", playersMap);
                gameState.put("type", "game_state");

                // Send to all players in the room
                broadcastToRoom(playerRoom, gameState);
            } else {
                // Send an individual confirmation to this player even if not in a room
                Map<String, Object> response = new HashMap<>();
                response.put("type", "position_updated");
                sendMessage(session, response);
            }
        }

        private void handleHit(WebSocketSession session, Map<String, Object> request) throws IOException {
            // Get player ID associated with this session
            String sessionId = session.getId();
            String attackerId = sessionToPlayerId.get(sessionId);

            if (attackerId == null) {
                sendError(session, "Attacker not found");
                return;
            }

            // Get target player ID
            String targetId = (String) request.get("targetId");
            if (targetId == null || targetId.isEmpty()) {
                sendError(session, "Target ID is required");
                return;
            }

            // Get the players
            Player attacker = players.get(attackerId);
            Player target = players.get(targetId);

            if (attacker == null) {
                sendError(session, "Attacker not found in registry");
                return;
            }

            if (target == null) {
                sendError(session, "Target not found in registry");
                return;
            }

            // Get hit point
            Map<String, Object> hitPoint = (Map<String, Object>) request.get("hitPoint");

            // Calculate damage based on hit location
            int damage = 10; // Default damage

            if (hitPoint != null) {
                double x = ((Number) hitPoint.get("x")).doubleValue();
                double y = ((Number) hitPoint.get("y")).doubleValue();

                // Use hitbox to determine hit part and damage multiplier
                Vector2 hitPointVector = new Vector2((float) x, (float) y);
                HitBoxPart hitPart = target.getHitBox().getHitPart(hitPointVector);

                // Apply damage with multiplier
                damage = (int) (damage * hitPart.getDamageMultiplier());
            }

            // Apply damage to target
            int currentHealth = target.getHealth();
            target.setHealth(Math.max(0, currentHealth - damage));

            System.out.println("Hit: " + attackerId + " hit " + targetId + " for " + damage
                    + " damage. Remaining health: " + target.getHealth());

            // Find which room the players are in
            Room playerRoom = null;
            for (Room room : rooms.values()) {
                if (room.getPlayers().containsKey(attackerId) && room.getPlayers().containsKey(targetId)) {
                    playerRoom = room;
                    break;
                }
            }

            // Create a hit confirmation response
            Map<String, Object> hitResponse = new HashMap<>();
            hitResponse.put("type", "hit_confirmed");
            hitResponse.put("attackerId", attackerId);
            hitResponse.put("targetId", targetId);
            hitResponse.put("damage", damage);
            hitResponse.put("remainingHealth", target.getHealth());

            // First send direct hit confirmation to the attacker
            sendMessage(session, hitResponse);

            // Then broadcast to all players in the room if in a room
            if (playerRoom != null) {
                // Broadcast game state update to all players in the room
                Map<String, Object> gameState = new HashMap<>();
                Map<String, Object> playersMap = new HashMap<>();

                for (Player p : playerRoom.getPlayers().values()) {
                    playersMap.put(p.getId(), p);
                }

                gameState.put("players", playersMap);
                gameState.put("type", "game_state");

                // Send to all players in the room
                broadcastToRoom(playerRoom, gameState);
            }
        }

        private void broadcastRoomList() {
            List<Map<String, Object>> roomList = new ArrayList<>();

            // Convert rooms to a list of maps
            for (Room room : rooms.values()) {
                if (!room.isStarted() && !room.isFull()) {
                    roomList.add(room.toMap());
                }
            }

            Map<String, Object> response = new HashMap<>();
            response.put("type", "room_list");
            response.put("rooms", roomList);

            broadcast(response);
        }

        private void sendError(WebSocketSession session, String message) throws IOException {
            Map<String, Object> response = new HashMap<>();
            response.put("type", "error");
            response.put("message", message);

            sendMessage(session, response);
        }

        private void sendMessage(WebSocketSession session, Map<String, Object> message) throws IOException {
            if (session.isOpen()) {
                session.sendMessage(new TextMessage(objectMapper.writeValueAsString(message)));
            }
        }

        @Override
        public void afterConnectionClosed(WebSocketSession session, org.springframework.web.socket.CloseStatus status)
                throws Exception {
            String sessionId = session.getId();
            String playerId = sessionToPlayerId.get(sessionId);

            // Remove player from any room
            if (playerId != null) {
                for (Room room : rooms.values()) {
                    if (room.getPlayers().containsKey(playerId)) {
                        room.removePlayer(playerId);

                        // If room is empty, remove it
                        if (room.getPlayerCount() == 0) {
                            rooms.remove(room.getId());
                        }

                        break;
                    }
                }

                // Remove player
                players.remove(playerId);
                sessionToPlayerId.remove(sessionId);
            }

            // Remove session
            sessions.remove(sessionId);
            System.out.println("WebSocket connection closed: " + sessionId + " with status: " + status);

            // Broadcast room list update to all connected clients
            broadcastRoomList();
        }

        public void broadcast(Map<String, Object> message) {
            try {
                TextMessage textMessage = new TextMessage(objectMapper.writeValueAsString(message));
                sessions.forEach((id, session) -> {
                    try {
                        if (session.isOpen()) {
                            session.sendMessage(textMessage);
                        }
                    } catch (IOException e) {
                        System.err.println("Error broadcasting message to session " + id + ": " + e.getMessage());
                    }
                });
            } catch (Exception e) {
                System.err.println("Error serializing broadcast message: " + e.getMessage());
            }
        }

        private void broadcastToRoom(Room room, Map<String, Object> message) {
            try {
                TextMessage textMessage = new TextMessage(objectMapper.writeValueAsString(message));

                for (Player player : room.getPlayers().values()) {
                    String playerId = player.getId();

                    // Find session for this player
                    String sessionId = null;
                    for (Map.Entry<String, String> entry : sessionToPlayerId.entrySet()) {
                        if (entry.getValue().equals(playerId)) {
                            sessionId = entry.getKey();
                            break;
                        }
                    }

                    if (sessionId != null) {
                        WebSocketSession playerSession = sessions.get(sessionId);
                        if (playerSession != null && playerSession.isOpen()) {
                            try {
                                playerSession.sendMessage(textMessage);
                            } catch (IOException e) {
                                System.err
                                        .println("Error sending message to player " + playerId + ": " + e.getMessage());
                            }
                        }
                    }
                }
            } catch (Exception e) {
                System.err.println("Error serializing broadcast message: " + e.getMessage());
            }
        }
    }
}