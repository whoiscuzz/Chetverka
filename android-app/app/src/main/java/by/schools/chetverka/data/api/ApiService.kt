package by.schools.chetverka.data.api

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Query

interface ApiService {

    @POST("login")
    suspend fun login(@Body request: LoginRequest): LoginResponse

    @GET("parse")
    suspend fun loadDiary(
        @Query("sessionid") sessionId: String,
        @Query("pupilid") pupilId: String
    ): DiaryResponse
}
