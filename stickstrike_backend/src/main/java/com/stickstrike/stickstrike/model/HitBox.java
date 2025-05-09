package com.stickstrike.stickstrike.model;

public class HitBox {
    private Vector2 position;
    private float radius;
    private HitBoxPart[] parts;

    public HitBox() {
        this.position = new Vector2();
        this.radius = 20.0f;
        this.parts = new HitBoxPart[] {
                new HitBoxPart("head", 1.5f), // Голова - 1.5x урона
                new HitBoxPart("body", 1.0f), // Тело - обычный урон
                new HitBoxPart("legs", 0.7f) // Ноги - 0.7x урона
        };
    }

    public Vector2 getPosition() {
        return position;
    }

    public void setPosition(Vector2 position) {
        this.position = position;
    }

    public float getRadius() {
        return radius;
    }

    public void setRadius(float radius) {
        this.radius = radius;
    }

    public HitBoxPart[] getParts() {
        return parts;
    }

    public void setParts(HitBoxPart[] parts) {
        this.parts = parts;
    }

    public HitBoxPart getHitPart(Vector2 hitPoint) {
        // Простая логика определения части тела по высоте
        float relativeY = hitPoint.y - position.y;
        if (relativeY < -radius * 0.3) {
            return parts[0]; // Голова
        } else if (relativeY > radius * 0.3) {
            return parts[2]; // Ноги
        } else {
            return parts[1]; // Тело
        }
    }
}