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
}
