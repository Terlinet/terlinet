package com.example.terlinet.api

import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.converter.scalars.ScalarsConverterFactory
import retrofit2.http.Body
import retrofit2.http.POST

data class QueryRequest(val text: String)

interface TerlineTApi {
    @POST("/query")
    suspend fun sendQuery(@Body request: QueryRequest): String

    companion object {
        // Use 10.0.2.2 para acessar o localhost do PC a partir do emulador Android
        private const val BASE_URL = "http://10.0.2.2:7860/" 

        fun create(): TerlineTApi {
            return Retrofit.Builder()
                .baseUrl(BASE_URL)
                .addConverterFactory(ScalarsConverterFactory.create()) // O seu servidor retorna string pura
                .addConverterFactory(GsonConverterFactory.create())
                .build()
                .create(TerlineTApi::class.java)
        }
    }
}
