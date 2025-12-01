package com.example.turnoshospi

data class PlantMembership(
    val plantId: String = "",
    val userId: String = "",
    val staffId: String? = null,
    val staffName: String? = null,
    val staffRole: String? = null
)
