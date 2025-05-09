package com.stickstrike.stickstrike.model;

public class HitBoxPart {
    private String name;
    private float damageMultiplier;

    public HitBoxPart(String name, float damageMultiplier) {
        this.name = name;
        this.damageMultiplier = damageMultiplier;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public float getDamageMultiplier() {
        return damageMultiplier;
    }

    public void setDamageMultiplier(float damageMultiplier) {
        this.damageMultiplier = damageMultiplier;
    }
}