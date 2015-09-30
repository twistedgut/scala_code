package controllers

import javax.inject.Inject
import javax.ws.rs.PathParam
import com.wordnik.swagger.annotations.ApiParam
import play.api.libs.json.{JsValue, Json}

import scala.concurrent.Future
import play.api.Play.current
import play.api.mvc._
import play.api.libs.ws._
import play.api._
import scala.concurrent.Await

import scala.util.{Failure, Success}

class Products extends Controller {
  implicit val context = play.api.libs.concurrent.Execution.Implicits.defaultContext
  def fetch = Action {
//    val url1 = "http://public-lad.salad.net-a-porter.com/NAP/GB/en/detail/349335"
//    val url2 = "http://public-lad.salad.net-a-porter.com/NAP/GB/en/detail/367157"
//    val fooFuture = WS.url(url1)get()
//    val barFuture = WS.url(url2)get()
//    for {
//      foo <- fooFuture
//      bar <- barFuture
//    } yield Ok(foo.body)



//    def readBox(@ApiParam(value = "Box identifer") @PathParam("code")  code: String) = Action.async { request =>
//      boxes.readBox(code).map(b => Ok(Json.toJson(b)))
//    }


//    val griff = retrieveLadProduct()
//    griff onComplete {
//      case Success(p)    => println(p)
//      case Failure(ex)   => println("FAIL")
//    }
//    Ok(views.html.index("Boooooo"))//retrieveLadProduct()))

//    val result = readBox("box1").apply(emptyRequest)
//    status(result) mustEqual 200
//    contentAsJson(result) mustEqual Json.toJson(box)


//    def feedTitle(feedUrl: String) = Action {
//      Async {
//        WS.url(feedUrl).get().map { response =>
//          Ok("Feed title: " + (response.json \ "title").as[String])
//        }
//      }
//    }


    val griff = contentAsString
    Ok(views.html.index(griff))
  }

    def retrieveLadProduct(): Future[String] = {
      val url1 = "http://public-lad.salad.net-a-porter.com/NAP/GB/en/detail/349335"
      val url2 = "http://public-lad.salad.net-a-porter.com/NAP/GB/en/detail/367157"
      val fooFuture: Future[WSResponse] = WS.url(url1)get()
      val barFuture: Future[WSResponse] = WS.url(url2)get()

      for {
        foo <- fooFuture.map{response => (response.json).as[String]}
        foo2 <- fooFuture.map(f => f.body)
        bar <- barFuture.map(f => f.body)
      } yield foo
    }

//  def readLad(): String = {
//    val mooney = retrieveLadProduct()
//    mooney onComplete(
//      case p => p
//      )
//    }
  }

//  def processProductList(products: List[String]): String = {
//    for (product <- products) {
//      val lad_url = "http://public-lad.salad.net-a-porter.com/NAP/GB/en/detail/" + product
//
//    }
//
//    "Boo"
//  }

//  def retrieveLadProduct(ladUrl: String): Future[String] = {
//    implicit val context = play.api.libs.concurrent.Execution.Implicits.defaultContext
//    val url1 = "http://public-lad.salad.net-a-porter.com/NAP/GB/en/detail/349335"
//    val url2 = "http://public-lad.salad.net-a-porter.com/NAP/GB/en/detail/367157"
//    val fooFuture: Future[WSResponse] = WS.url(url1)get()
//    val barFuture: Future[WSResponse] = WS.url(url2)get()
//
//    for {
//      foo <- fooFuture.map(f => f.json)
//      bar <- barFuture.map(f => f.json)
//    } yield foo
//  }

}


