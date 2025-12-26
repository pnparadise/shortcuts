package com.shortcuts.shortcuts.dsl

import com.google.gson.annotations.SerializedName

sealed interface Action {
    val type: String
    val id: String

    data class Fetch(
        override val id: String = java.util.UUID.randomUUID().toString(),
        val url: String = "",
        val method: String = "GET",
        val headers: Map<String, String> = emptyMap(),
        val body: String? = null,
        val targetVar: String = "response"
    ) : Action {
        override val type: String = "Fetch"
    }

    data class If(
        override val id: String = java.util.UUID.randomUUID().toString(),
        val conditionExpression: String = "",
        val trueFlow: List<Action> = emptyList(),
        val falseFlow: List<Action> = emptyList()
    ) : Action {
        override val type: String = "If"
    }

    data class SetView(
        override val id: String = java.util.UUID.randomUUID().toString(),
        val textTemplate: String = ""
    ) : Action {
        override val type: String = "SetView"
    }

    data class Toast(
        override val id: String = java.util.UUID.randomUUID().toString(),
        val messageTemplate: String = ""
    ) : Action {
        override val type: String = "Toast"
    }

    data class Return(
        override val id: String = java.util.UUID.randomUUID().toString(),
        val stop: Boolean = true
    ) : Action {
        override val type: String = "Return"
    }

    data class Clipboard(
        override val id: String = java.util.UUID.randomUUID().toString(),
        val mode: String = "READ",
        val targetVar: String = "clip",
        val textTemplate: String = ""
    ) : Action {
        override val type: String = "Clipboard"
    }

    data class Intent(
        override val id: String = java.util.UUID.randomUUID().toString(),
        val action: String = "android.intent.action.VIEW",
        val packageName: String = "",
        val className: String? = null,
        val dataUri: String = "",
        val extras: Map<String, String> = emptyMap()
    ) : Action {
        override val type: String = "Intent"
    }

    data class Notification(
        override val id: String = java.util.UUID.randomUUID().toString(),
        val title: String = "",
        val message: String = "",
        val channelId: String = "shortcuts"
    ) : Action {
        override val type: String = "Notification"
    }

    data class Expression(
        override val id: String = java.util.UUID.randomUUID().toString(),
        val script: String = ""
    ) : Action {
        override val type: String = "Expression"
    }
}

