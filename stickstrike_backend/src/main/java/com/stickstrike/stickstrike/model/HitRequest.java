package com.stickstrike.stickstrike.model;

public class HitRequest {
    private String attackerId;
    private String targetId;
    private Vector2 hitPoint;

    public String getAttackerId() {
        return attackerId;
    }

    public void setAttackerId(String attackerId) {
        this.attackerId = attackerId;
    }

    public String getTargetId() {
        return targetId;
    }

    public void setTargetId(String targetId) {
        this.targetId = targetId;
    }

    public Vector2 getHitPoint() {
        return hitPoint;
    }

    public void setHitPoint(Vector2 hitPoint) {
        this.hitPoint = hitPoint;
    }
}