package com.shortcuts.shortcuts.utils

import com.google.gson.*
import com.google.gson.reflect.TypeToken
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonWriter
import java.io.IOException

class RuntimeTypeAdapterFactory<T>(
    private val baseType: Class<T>,
    private val typeFieldName: String,
    private val maintainType: Boolean = false
) : TypeAdapterFactory {

    private val labelToSubtype = LinkedHashMap<String, Class<*>>()
    private val subtypeToLabel = LinkedHashMap<Class<*>, String>()

    fun registerSubtype(type: Class<out T>, label: String = type.simpleName): RuntimeTypeAdapterFactory<T> {
        if (subtypeToLabel.containsKey(type) || labelToSubtype.containsKey(label)) {
            throw IllegalArgumentException("types and labels must be unique")
        }
        labelToSubtype[label] = type
        subtypeToLabel[type] = label
        return this
    }

    override fun <R : Any?> create(gson: Gson, type: TypeToken<R>): TypeAdapter<R>? {
        if (type.rawType != baseType) {
            return null
        }

        val labelToDelegate = LinkedHashMap<String, TypeAdapter<*>>()
        val subtypeToDelegate = LinkedHashMap<Class<*>, TypeAdapter<*>>()

        for ((label, subtype) in labelToSubtype) {
            val delegate = gson.getDelegateAdapter(this, TypeToken.get(subtype))
            labelToDelegate[label] = delegate
            subtypeToDelegate[subtype] = delegate
        }

        return object : TypeAdapter<R>() {
            @Throws(IOException::class)
            override fun read(`in`: JsonReader): R? {
                val jsonElement = JsonParser.parseReader(`in`) // Use public API
                if (jsonElement.isJsonNull) return null
                
                val jsonObject = jsonElement.asJsonObject
                val labelElement = if (maintainType) {
                    jsonObject.get(typeFieldName)
                } else {
                    jsonObject.remove(typeFieldName)
                }

                if (labelElement == null) {
                     throw JsonParseException("cannot deserialize $baseType because it does not define a field named $typeFieldName")
                }
                
                val label = labelElement.asString
                val delegate = labelToDelegate[label] as? TypeAdapter<R> 
                    ?: throw JsonParseException("cannot deserialize $baseType subtype named $label; did you forget to register a subtype?")
                    
                return delegate.fromJsonTree(jsonElement)
            }

            @Throws(IOException::class)
            override fun write(out: JsonWriter, value: R?) {
                if (value == null) {
                    out.nullValue()
                    return
                }
                
                val srcType = value.javaClass
                val label = subtypeToLabel[srcType]
                val delegate = subtypeToDelegate[srcType] as? TypeAdapter<R>
                    ?: throw JsonParseException("cannot serialize ${srcType.name}; did you forget to register a subtype?")

                val jsonObject = delegate.toJsonTree(value).asJsonObject

                if (maintainType) {
                    gson.getAdapter(JsonElement::class.java).write(out, jsonObject)
                    return
                }

                val clone = JsonObject()
                if (jsonObject.has(typeFieldName)) {
                    throw JsonParseException("cannot serialize ${srcType.name} because it already defines a field named $typeFieldName")
                }
                clone.add(typeFieldName, JsonPrimitive(label))
                
                for ((key, elem) in jsonObject.entrySet()) {
                    clone.add(key, elem)
                }
                
                gson.getAdapter(JsonElement::class.java).write(out, clone)
            }
        }.nullSafe()
    }

    companion object {
        @JvmStatic
        fun <T> of(baseType: Class<T>, typeFieldName: String = "type"): RuntimeTypeAdapterFactory<T> {
            return RuntimeTypeAdapterFactory(baseType, typeFieldName, false)
        }
    }
}
