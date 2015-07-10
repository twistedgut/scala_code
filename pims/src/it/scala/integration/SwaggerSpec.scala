package integration

class SwaggerSpec extends IntegrationTest {

  "The /Swagger endpoint" should {
    "return valid JSON data" in new WithApp {

      val response = await(request("/swagger/").get())
      response.status must equalTo (200)

      // This will throw an exception if the returned body can not be parsed as valid JSON
      response.json
    }
  }
}
