package com.shortcuts.shortcuts.utils

import com.google.gson.Gson
import com.google.gson.GsonBuilder

import com.shortcuts.shortcuts.dsl.Action

object GsonHelper {
    val gson: Gson by lazy {
        val actionAdapterFactory = RuntimeTypeAdapterFactory.of(Action::class.java, "type")
            .registerSubtype(Action.Fetch::class.java, "Fetch")
            .registerSubtype(Action.If::class.java, "If")
            .registerSubtype(Action.SetView::class.java, "SetView")
            .registerSubtype(Action.Toast::class.java, "Toast")

        GsonBuilder()
            .registerTypeAdapterFactory(actionAdapterFactory)
            .create()
    }
}
