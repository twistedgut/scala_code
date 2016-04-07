package controllers

import database.Tables
import play.api.mvc.Controller
import repository._

trait SmcController extends Controller
  with Tables
  with PostgresDatabase
  with SlickHealth
  with SlickOptions
  with SlickShippingOption
  with SlickDeliveryRestrictions