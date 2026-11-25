package com.home.clash.service.models

data class NotificationParams(
    val title: String = "HomeClash",
    val stopText: String = "STOP",
    val onlyStatisticsProxy: Boolean = false,
    val showStopAction: Boolean = true,
)
