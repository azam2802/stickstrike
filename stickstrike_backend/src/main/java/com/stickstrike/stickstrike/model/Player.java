package com.stickstrike.stickstrike.model;

public class Player {
    private String id;
    private String name;
    private int health;
    private Vector2 position;
    private Vector2 velocity;
    private HitBox hitBox;

    public Player(String id, String name) {
        this.id = id;
        this.name = name;
        this.health = 100;
        this.position = new Vector2(0, 0);
        this.velocity = new Vector2(0, 0);
        this.hitBox = new HitBox();
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public int getHealth() {
        return health;
    }

    public void setHealth(int health) {
        this.health = health;
    }

    public Vector2 getPosition() {
        return position;
    }

    public void setPosition(Vector2 position) {
        this.position = position;
    }

    public Vector2 getVelocity() {
        return velocity;
    }

    public void setVelocity(Vector2 velocity) {
        this.velocity = velocity;
    }

    public HitBox getHitBox() {
        return hitBox;
    }

    public void setHitBox(HitBox hitBox) {
        this.hitBox = hitBox;
    }
}