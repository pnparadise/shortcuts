package com.shortcuts.shortcuts.dsl

import com.google.gson.annotations.SerializedName

sealed interface Action {
    val type: String

    data class Fetch(
        val url: String = "",
        val method: String = "GET",
        val headers: Map<String, String> = emptyMap(),
        val body: String? = null,
        val targetVar: String = "response"
    ) : Action {
        override val type: String = "Fetch"
    }

    data class If(
        val conditionExpression: String = "",
        val trueFlow: List<Action> = emptyList(),
        val falseFlow: List<Action> = emptyList()
    ) : Action {
        override val type: String = "If"
    }

    data class SetView(
        val textTemplate: String = ""
    ) : Action {
        override val type: String = "SetView"
    }

    data class Toast(
        val messageTemplate: String = ""
    ) : Action {
        override val type: String = "Toast"
    }

    data class Return(
        val stop: Boolean = true
    ) : Action {
        override val type: String = "Return"
    }

    data class Clipboard(
        val mode: String = "READ",
        val targetVar: String = "clip",
        val textTemplate: String = ""
    ) : Action {
        override val type: String = "Clipboard"
    }

    data class Intent(
        val action: String = "android.intent.action.VIEW",
        val packageName: String = "",
        val className: String? = null,
        val dataUri: String = "",
        val extras: Map<String, String> = emptyMap()
    ) : Action {
        override val type: String = "Intent"
    }

    data class Notification(
        val title: String = "",
        val message: String = "",
        val channelId: String = "shortcuts"
    ) : Action {
        override val type: String = "Notification"
    }

    data class Expression(
        val script: String = ""
    ) : Action {
        override val type: String = "Expression"
    }
}

