package nap.database
// AUTO-GENERATED Slick data model
/** Stand-alone Slick data model for immediate use */
object Tables extends {
  val profile = slick.driver.PostgresDriver
} with Tables

/** Slick data model trait for extension, choice of backend or usage in the cake pattern. (Make sure to initialize this late.) */
trait Tables {
  val profile: slick.driver.JdbcProfile
  import profile.api._
  import slick.model.ForeignKeyAction
  // NOTE: GetResult mappers for plain SQL are only generated for tables where Slick knows how to map the types of all columns.
  import slick.jdbc.{GetResult => GR}

  /** DDL for all tables. Call .create to execute. */
  lazy val schema: profile.SchemaDescription = Array(Attribute.schema, Availability.schema, AvailabilityGroup.schema, AvailabilityGroupMembers.schema, AvailabilityPostCodeGroup.schema, AvailabilityPromotionGroup.schema, AvailabilityRestriction.schema, Business.schema, Carrier.schema, Country.schema, CountryRestriction.schema, Currency.schema, CustomerSelectableTimezone.schema, Dc.schema, Description.schema, Division.schema, DivisionRestriction.schema, Event.schema, EventType.schema, File.schema, Language.schema, Locale.schema, PackagingGroup.schema, PostCode.schema, PostCodeGroup.schema, PostCodeGroupMember.schema, PostCodeRestriction.schema, PromotionGroup.schema, Restriction.schema, ShippingOption.schema, SignatureRequiredStatus.schema, Stage.schema, StageDaysToComplete.schema).reduceLeft(_ ++ _)
  @deprecated("Use .schema instead of .ddl", "3.0")
  def ddl = schema

  /** Entity class storing rows of table Attribute
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text) */
  case class AttributeRow(id: Int, name: String, code: String)
  /** GetResult implicit for fetching AttributeRow objects using plain SQL queries */
  implicit def GetResultAttributeRow(implicit e0: GR[Int], e1: GR[String]): GR[AttributeRow] = GR{
    prs => import prs._
    AttributeRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table attribute. Objects of this class serve as prototypes for rows in queries. */
  class Attribute(_tableTag: Tag) extends Table[AttributeRow](_tableTag, Some("shipping"), "attribute") {
    def * = (id, name, code) <> (AttributeRow.tupled, AttributeRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code)).shaped.<>({r=>import r._; _1.map(_=> AttributeRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")

    /** Uniqueness Index over (code) (database name attribute_code_key) */
    val index1 = index("attribute_code_key", code, unique=true)
  }
  /** Collection-like TableQuery object for table Attribute */
  lazy val Attribute = new TableQuery(tag => new Attribute(tag))

  /** Entity class storing rows of table Availability
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param optionId Database column option_id SqlType(int4)
   *  @param countryId Database column country_id SqlType(int4), Default(None)
   *  @param businessId Database column business_id SqlType(int4)
   *  @param isEnabled Database column is_enabled SqlType(bool)
   *  @param isCustomerFacing Database column is_customer_facing SqlType(bool)
   *  @param price Database column price SqlType(numeric)
   *  @param currencyId Database column currency_id SqlType(int4)
   *  @param doesPriceIncludeTax Database column does_price_include_tax SqlType(bool)
   *  @param legacySku Database column legacy_sku SqlType(text)
   *  @param createdAt Database column created_at SqlType(timestamptz)
   *  @param signatureRequiredStatusId Database column signature_required_status_id SqlType(int4)
   *  @param customerSelectableCutoffTime Database column customer_selectable_cutoff_time SqlType(time), Default(None)
   *  @param customerSelectableOffset Database column customer_selectable_offset SqlType(int4), Default(None)
   *  @param divisionId Database column division_id SqlType(int4), Default(None)
   *  @param postCodeGroupId Database column post_code_group_id SqlType(int4), Default(None)
   *  @param packagingGroupId Database column packaging_group_id SqlType(int4), Default(None)
   *  @param dc Database column DC SqlType(varchar), Length(10,true)
   *  @param customerSelectableCutoffTimezoneId Database column customer_selectable_cutoff_timezone_id SqlType(int4), Default(1) */
  case class AvailabilityRow(id: Int, optionId: Int, countryId: Option[Int] = None, businessId: Int, isEnabled: Boolean, isCustomerFacing: Boolean, price: scala.math.BigDecimal, currencyId: Int, doesPriceIncludeTax: Boolean, legacySku: String, createdAt: java.sql.Timestamp, signatureRequiredStatusId: Int, customerSelectableCutoffTime: Option[java.sql.Time] = None, customerSelectableOffset: Option[Int] = None, divisionId: Option[Int] = None, postCodeGroupId: Option[Int] = None, packagingGroupId: Option[Int] = None, dc: String, customerSelectableCutoffTimezoneId: Int = 1)
  /** GetResult implicit for fetching AvailabilityRow objects using plain SQL queries */
  implicit def GetResultAvailabilityRow(implicit e0: GR[Int], e1: GR[Option[Int]], e2: GR[Boolean], e3: GR[scala.math.BigDecimal], e4: GR[String], e5: GR[java.sql.Timestamp], e6: GR[Option[java.sql.Time]]): GR[AvailabilityRow] = GR{
    prs => import prs._
    AvailabilityRow.tupled((<<[Int], <<[Int], <<?[Int], <<[Int], <<[Boolean], <<[Boolean], <<[scala.math.BigDecimal], <<[Int], <<[Boolean], <<[String], <<[java.sql.Timestamp], <<[Int], <<?[java.sql.Time], <<?[Int], <<?[Int], <<?[Int], <<?[Int], <<[String], <<[Int]))
  }
  /** Table description of table availability. Objects of this class serve as prototypes for rows in queries. */
  class Availability(_tableTag: Tag) extends Table[AvailabilityRow](_tableTag, Some("shipping"), "availability") {
    def * = (id, optionId, countryId, businessId, isEnabled, isCustomerFacing, price, currencyId, doesPriceIncludeTax, legacySku, createdAt, signatureRequiredStatusId, customerSelectableCutoffTime, customerSelectableOffset, divisionId, postCodeGroupId, packagingGroupId, dc, customerSelectableCutoffTimezoneId) <> (AvailabilityRow.tupled, AvailabilityRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(optionId), countryId, Rep.Some(businessId), Rep.Some(isEnabled), Rep.Some(isCustomerFacing), Rep.Some(price), Rep.Some(currencyId), Rep.Some(doesPriceIncludeTax), Rep.Some(legacySku), Rep.Some(createdAt), Rep.Some(signatureRequiredStatusId), customerSelectableCutoffTime, customerSelectableOffset, divisionId, postCodeGroupId, packagingGroupId, Rep.Some(dc), Rep.Some(customerSelectableCutoffTimezoneId)).shaped.<>({r=>import r._; _1.map(_=> AvailabilityRow.tupled((_1.get, _2.get, _3, _4.get, _5.get, _6.get, _7.get, _8.get, _9.get, _10.get, _11.get, _12.get, _13, _14, _15, _16, _17, _18.get, _19.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column option_id SqlType(int4) */
    val optionId: Rep[Int] = column[Int]("option_id")
    /** Database column country_id SqlType(int4), Default(None) */
    val countryId: Rep[Option[Int]] = column[Option[Int]]("country_id", O.Default(None))
    /** Database column business_id SqlType(int4) */
    val businessId: Rep[Int] = column[Int]("business_id")
    /** Database column is_enabled SqlType(bool) */
    val isEnabled: Rep[Boolean] = column[Boolean]("is_enabled")
    /** Database column is_customer_facing SqlType(bool) */
    val isCustomerFacing: Rep[Boolean] = column[Boolean]("is_customer_facing")
    /** Database column price SqlType(numeric) */
    val price: Rep[scala.math.BigDecimal] = column[scala.math.BigDecimal]("price")
    /** Database column currency_id SqlType(int4) */
    val currencyId: Rep[Int] = column[Int]("currency_id")
    /** Database column does_price_include_tax SqlType(bool) */
    val doesPriceIncludeTax: Rep[Boolean] = column[Boolean]("does_price_include_tax")
    /** Database column legacy_sku SqlType(text) */
    val legacySku: Rep[String] = column[String]("legacy_sku")
    /** Database column created_at SqlType(timestamptz) */
    val createdAt: Rep[java.sql.Timestamp] = column[java.sql.Timestamp]("created_at")
    /** Database column signature_required_status_id SqlType(int4) */
    val signatureRequiredStatusId: Rep[Int] = column[Int]("signature_required_status_id")
    /** Database column customer_selectable_cutoff_time SqlType(time), Default(None) */
    val customerSelectableCutoffTime: Rep[Option[java.sql.Time]] = column[Option[java.sql.Time]]("customer_selectable_cutoff_time", O.Default(None))
    /** Database column customer_selectable_offset SqlType(int4), Default(None) */
    val customerSelectableOffset: Rep[Option[Int]] = column[Option[Int]]("customer_selectable_offset", O.Default(None))
    /** Database column division_id SqlType(int4), Default(None) */
    val divisionId: Rep[Option[Int]] = column[Option[Int]]("division_id", O.Default(None))
    /** Database column post_code_group_id SqlType(int4), Default(None) */
    val postCodeGroupId: Rep[Option[Int]] = column[Option[Int]]("post_code_group_id", O.Default(None))
    /** Database column packaging_group_id SqlType(int4), Default(None) */
    val packagingGroupId: Rep[Option[Int]] = column[Option[Int]]("packaging_group_id", O.Default(None))
    /** Database column DC SqlType(varchar), Length(10,true) */
    val dc: Rep[String] = column[String]("DC", O.Length(10,varying=true))
    /** Database column customer_selectable_cutoff_timezone_id SqlType(int4), Default(1) */
    val customerSelectableCutoffTimezoneId: Rep[Int] = column[Int]("customer_selectable_cutoff_timezone_id", O.Default(1))

    /** Foreign key referencing Business (database name availability_business_id_fkey) */
    lazy val businessFk = foreignKey("availability_business_id_fkey", businessId, Business)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Country (database name availability_country_id_fkey) */
    lazy val countryFk = foreignKey("availability_country_id_fkey", countryId, Country)(r => Rep.Some(r.id), onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Currency (database name availability_currency_id_fkey) */
    lazy val currencyFk = foreignKey("availability_currency_id_fkey", currencyId, Currency)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing CustomerSelectableTimezone (database name availability_customer_selectable_cutoff_timezone_id_fkey) */
    lazy val customerSelectableTimezoneFk = foreignKey("availability_customer_selectable_cutoff_timezone_id_fkey", customerSelectableCutoffTimezoneId, CustomerSelectableTimezone)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Dc (database name availability_DC_fkey) */
    lazy val dcFk = foreignKey("availability_DC_fkey", dc, Dc)(r => r.code, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Division (database name availability_division_id_fkey) */
    lazy val divisionFk = foreignKey("availability_division_id_fkey", divisionId, Division)(r => Rep.Some(r.id), onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing ShippingOption (database name availability_option_id_fkey) */
    lazy val shippingOptionFk = foreignKey("availability_option_id_fkey", optionId, ShippingOption)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing PackagingGroup (database name availability_packaging_group_id_fkey) */
    lazy val packagingGroupFk = foreignKey("availability_packaging_group_id_fkey", packagingGroupId, PackagingGroup)(r => Rep.Some(r.id), onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing PostCodeGroup (database name availability_post_code_group_id_fkey) */
    lazy val postCodeGroupFk = foreignKey("availability_post_code_group_id_fkey", postCodeGroupId, PostCodeGroup)(r => Rep.Some(r.id), onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing SignatureRequiredStatus (database name availability_signature_required_status_id_fkey) */
    lazy val signatureRequiredStatusFk = foreignKey("availability_signature_required_status_id_fkey", signatureRequiredStatusId, SignatureRequiredStatus)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)

    /** Uniqueness Index over (optionId,businessId,countryId,dc) (database name availability_option_id_business_id_country_id_dc_key) */
    val index1 = index("availability_option_id_business_id_country_id_dc_key", (optionId, businessId, countryId, dc), unique=true)
    /** Uniqueness Index over (optionId,businessId,divisionId,dc) (database name option_id_business_id_division_id_dc_key) */
    val index2 = index("option_id_business_id_division_id_dc_key", (optionId, businessId, divisionId, dc), unique=true)
    /** Uniqueness Index over (optionId,businessId,postCodeGroupId,dc) (database name option_id_business_id_post_code_group_id_dc_key) */
    val index3 = index("option_id_business_id_post_code_group_id_dc_key", (optionId, businessId, postCodeGroupId, dc), unique=true)
  }
  /** Collection-like TableQuery object for table Availability */
  lazy val Availability = new TableQuery(tag => new Availability(tag))

  /** Entity class storing rows of table AvailabilityGroup
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text) */
  case class AvailabilityGroupRow(id: Int, name: String, code: String)
  /** GetResult implicit for fetching AvailabilityGroupRow objects using plain SQL queries */
  implicit def GetResultAvailabilityGroupRow(implicit e0: GR[Int], e1: GR[String]): GR[AvailabilityGroupRow] = GR{
    prs => import prs._
    AvailabilityGroupRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table availability_group. Objects of this class serve as prototypes for rows in queries. */
  class AvailabilityGroup(_tableTag: Tag) extends Table[AvailabilityGroupRow](_tableTag, Some("shipping"), "availability_group") {
    def * = (id, name, code) <> (AvailabilityGroupRow.tupled, AvailabilityGroupRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code)).shaped.<>({r=>import r._; _1.map(_=> AvailabilityGroupRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")
  }
  /** Collection-like TableQuery object for table AvailabilityGroup */
  lazy val AvailabilityGroup = new TableQuery(tag => new AvailabilityGroup(tag))

  /** Entity class storing rows of table AvailabilityGroupMembers
   *  @param availabilityId Database column availability_id SqlType(int4)
   *  @param availabilityGroupId Database column availability_group_id SqlType(int4) */
  case class AvailabilityGroupMembersRow(availabilityId: Int, availabilityGroupId: Int)
  /** GetResult implicit for fetching AvailabilityGroupMembersRow objects using plain SQL queries */
  implicit def GetResultAvailabilityGroupMembersRow(implicit e0: GR[Int]): GR[AvailabilityGroupMembersRow] = GR{
    prs => import prs._
    AvailabilityGroupMembersRow.tupled((<<[Int], <<[Int]))
  }
  /** Table description of table availability_group_members. Objects of this class serve as prototypes for rows in queries. */
  class AvailabilityGroupMembers(_tableTag: Tag) extends Table[AvailabilityGroupMembersRow](_tableTag, Some("shipping"), "availability_group_members") {
    def * = (availabilityId, availabilityGroupId) <> (AvailabilityGroupMembersRow.tupled, AvailabilityGroupMembersRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(availabilityId), Rep.Some(availabilityGroupId)).shaped.<>({r=>import r._; _1.map(_=> AvailabilityGroupMembersRow.tupled((_1.get, _2.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column availability_id SqlType(int4) */
    val availabilityId: Rep[Int] = column[Int]("availability_id")
    /** Database column availability_group_id SqlType(int4) */
    val availabilityGroupId: Rep[Int] = column[Int]("availability_group_id")

    /** Primary key of AvailabilityGroupMembers (database name availability_group_members_pkey) */
    val pk = primaryKey("availability_group_members_pkey", (availabilityId, availabilityGroupId))

    /** Foreign key referencing Availability (database name availability_group_members_availability_id_fkey) */
    lazy val availabilityFk = foreignKey("availability_group_members_availability_id_fkey", availabilityId, Availability)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing AvailabilityGroup (database name availability_group_members_availability_group_id_fkey) */
    lazy val availabilityGroupFk = foreignKey("availability_group_members_availability_group_id_fkey", availabilityGroupId, AvailabilityGroup)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
  }
  /** Collection-like TableQuery object for table AvailabilityGroupMembers */
  lazy val AvailabilityGroupMembers = new TableQuery(tag => new AvailabilityGroupMembers(tag))

  /** Entity class storing rows of table AvailabilityPostCodeGroup
   *  @param availabilityId Database column availability_id SqlType(int4)
   *  @param postCodeGroupId Database column post_code_group_id SqlType(int4)
   *  @param isIncluded Database column is_included SqlType(bool) */
  case class AvailabilityPostCodeGroupRow(availabilityId: Int, postCodeGroupId: Int, isIncluded: Boolean)
  /** GetResult implicit for fetching AvailabilityPostCodeGroupRow objects using plain SQL queries */
  implicit def GetResultAvailabilityPostCodeGroupRow(implicit e0: GR[Int], e1: GR[Boolean]): GR[AvailabilityPostCodeGroupRow] = GR{
    prs => import prs._
    AvailabilityPostCodeGroupRow.tupled((<<[Int], <<[Int], <<[Boolean]))
  }
  /** Table description of table availability_post_code_group. Objects of this class serve as prototypes for rows in queries. */
  class AvailabilityPostCodeGroup(_tableTag: Tag) extends Table[AvailabilityPostCodeGroupRow](_tableTag, Some("shipping"), "availability_post_code_group") {
    def * = (availabilityId, postCodeGroupId, isIncluded) <> (AvailabilityPostCodeGroupRow.tupled, AvailabilityPostCodeGroupRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(availabilityId), Rep.Some(postCodeGroupId), Rep.Some(isIncluded)).shaped.<>({r=>import r._; _1.map(_=> AvailabilityPostCodeGroupRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column availability_id SqlType(int4) */
    val availabilityId: Rep[Int] = column[Int]("availability_id")
    /** Database column post_code_group_id SqlType(int4) */
    val postCodeGroupId: Rep[Int] = column[Int]("post_code_group_id")
    /** Database column is_included SqlType(bool) */
    val isIncluded: Rep[Boolean] = column[Boolean]("is_included")

    /** Primary key of AvailabilityPostCodeGroup (database name availability_post_code_group_pkey) */
    val pk = primaryKey("availability_post_code_group_pkey", (availabilityId, postCodeGroupId))

    /** Foreign key referencing Availability (database name availability_post_code_group_availability_id_fkey) */
    lazy val availabilityFk = foreignKey("availability_post_code_group_availability_id_fkey", availabilityId, Availability)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing PostCodeGroup (database name availability_post_code_group_post_code_group_id_fkey) */
    lazy val postCodeGroupFk = foreignKey("availability_post_code_group_post_code_group_id_fkey", postCodeGroupId, PostCodeGroup)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)

    /** Index over (isIncluded) (database name ship_av_post_code_group_isinc_idx) */
    val index1 = index("ship_av_post_code_group_isinc_idx", isIncluded)
  }
  /** Collection-like TableQuery object for table AvailabilityPostCodeGroup */
  lazy val AvailabilityPostCodeGroup = new TableQuery(tag => new AvailabilityPostCodeGroup(tag))

  /** Entity class storing rows of table AvailabilityPromotionGroup
   *  @param availabilityId Database column availability_id SqlType(int4)
   *  @param promotionGroupId Database column promotion_group_id SqlType(int4) */
  case class AvailabilityPromotionGroupRow(availabilityId: Int, promotionGroupId: Int)
  /** GetResult implicit for fetching AvailabilityPromotionGroupRow objects using plain SQL queries */
  implicit def GetResultAvailabilityPromotionGroupRow(implicit e0: GR[Int]): GR[AvailabilityPromotionGroupRow] = GR{
    prs => import prs._
    AvailabilityPromotionGroupRow.tupled((<<[Int], <<[Int]))
  }
  /** Table description of table availability_promotion_group. Objects of this class serve as prototypes for rows in queries. */
  class AvailabilityPromotionGroup(_tableTag: Tag) extends Table[AvailabilityPromotionGroupRow](_tableTag, Some("shipping"), "availability_promotion_group") {
    def * = (availabilityId, promotionGroupId) <> (AvailabilityPromotionGroupRow.tupled, AvailabilityPromotionGroupRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(availabilityId), Rep.Some(promotionGroupId)).shaped.<>({r=>import r._; _1.map(_=> AvailabilityPromotionGroupRow.tupled((_1.get, _2.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column availability_id SqlType(int4) */
    val availabilityId: Rep[Int] = column[Int]("availability_id")
    /** Database column promotion_group_id SqlType(int4) */
    val promotionGroupId: Rep[Int] = column[Int]("promotion_group_id")

    /** Primary key of AvailabilityPromotionGroup (database name availability_promotion_group_pkey) */
    val pk = primaryKey("availability_promotion_group_pkey", (availabilityId, promotionGroupId))

    /** Foreign key referencing Availability (database name availability_promotion_group_availability_id_fkey) */
    lazy val availabilityFk = foreignKey("availability_promotion_group_availability_id_fkey", availabilityId, Availability)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing PromotionGroup (database name availability_promotion_group_promotion_group_id_fkey) */
    lazy val promotionGroupFk = foreignKey("availability_promotion_group_promotion_group_id_fkey", promotionGroupId, PromotionGroup)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
  }
  /** Collection-like TableQuery object for table AvailabilityPromotionGroup */
  lazy val AvailabilityPromotionGroup = new TableQuery(tag => new AvailabilityPromotionGroup(tag))

  /** Entity class storing rows of table AvailabilityRestriction
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param attributeId Database column attribute_id SqlType(int4)
   *  @param availabilityId Database column availability_id SqlType(int4) */
  case class AvailabilityRestrictionRow(id: Int, attributeId: Int, availabilityId: Int)
  /** GetResult implicit for fetching AvailabilityRestrictionRow objects using plain SQL queries */
  implicit def GetResultAvailabilityRestrictionRow(implicit e0: GR[Int]): GR[AvailabilityRestrictionRow] = GR{
    prs => import prs._
    AvailabilityRestrictionRow.tupled((<<[Int], <<[Int], <<[Int]))
  }
  /** Table description of table availability_restriction. Objects of this class serve as prototypes for rows in queries. */
  class AvailabilityRestriction(_tableTag: Tag) extends Table[AvailabilityRestrictionRow](_tableTag, Some("shipping"), "availability_restriction") {
    def * = (id, attributeId, availabilityId) <> (AvailabilityRestrictionRow.tupled, AvailabilityRestrictionRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(attributeId), Rep.Some(availabilityId)).shaped.<>({r=>import r._; _1.map(_=> AvailabilityRestrictionRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column attribute_id SqlType(int4) */
    val attributeId: Rep[Int] = column[Int]("attribute_id")
    /** Database column availability_id SqlType(int4) */
    val availabilityId: Rep[Int] = column[Int]("availability_id")

    /** Foreign key referencing Attribute (database name availability_restriction_attribute_id_fkey) */
    lazy val attributeFk = foreignKey("availability_restriction_attribute_id_fkey", attributeId, Attribute)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Availability (database name availability_restriction_availability_id_fkey) */
    lazy val availabilityFk = foreignKey("availability_restriction_availability_id_fkey", availabilityId, Availability)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)

    /** Uniqueness Index over (attributeId,availabilityId) (database name idx_attribute_availability) */
    val index1 = index("idx_attribute_availability", (attributeId, availabilityId), unique=true)
  }
  /** Collection-like TableQuery object for table AvailabilityRestriction */
  lazy val AvailabilityRestriction = new TableQuery(tag => new AvailabilityRestriction(tag))

  /** Entity class storing rows of table Business
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text) */
  case class BusinessRow(id: Int, name: String, code: String)
  /** GetResult implicit for fetching BusinessRow objects using plain SQL queries */
  implicit def GetResultBusinessRow(implicit e0: GR[Int], e1: GR[String]): GR[BusinessRow] = GR{
    prs => import prs._
    BusinessRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table business. Objects of this class serve as prototypes for rows in queries. */
  class Business(_tableTag: Tag) extends Table[BusinessRow](_tableTag, "business") {
    def * = (id, name, code) <> (BusinessRow.tupled, BusinessRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code)).shaped.<>({r=>import r._; _1.map(_=> BusinessRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")

    /** Uniqueness Index over (code) (database name business_code_key) */
    val index1 = index("business_code_key", code, unique=true)
  }
  /** Collection-like TableQuery object for table Business */
  lazy val Business = new TableQuery(tag => new Business(tag))

  /** Entity class storing rows of table Carrier
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text) */
  case class CarrierRow(id: Int, name: String, code: String)
  /** GetResult implicit for fetching CarrierRow objects using plain SQL queries */
  implicit def GetResultCarrierRow(implicit e0: GR[Int], e1: GR[String]): GR[CarrierRow] = GR{
    prs => import prs._
    CarrierRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table carrier. Objects of this class serve as prototypes for rows in queries. */
  class Carrier(_tableTag: Tag) extends Table[CarrierRow](_tableTag, "carrier") {
    def * = (id, name, code) <> (CarrierRow.tupled, CarrierRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code)).shaped.<>({r=>import r._; _1.map(_=> CarrierRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")

    /** Uniqueness Index over (code) (database name carrier_code_key) */
    val index1 = index("carrier_code_key", code, unique=true)
  }
  /** Collection-like TableQuery object for table Carrier */
  lazy val Carrier = new TableQuery(tag => new Carrier(tag))

  /** Entity class storing rows of table Country
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text) */
  case class CountryRow(id: Int, name: String, code: String)
  /** GetResult implicit for fetching CountryRow objects using plain SQL queries */
  implicit def GetResultCountryRow(implicit e0: GR[Int], e1: GR[String]): GR[CountryRow] = GR{
    prs => import prs._
    CountryRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table country. Objects of this class serve as prototypes for rows in queries. */
  class Country(_tableTag: Tag) extends Table[CountryRow](_tableTag, "country") {
    def * = (id, name, code) <> (CountryRow.tupled, CountryRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code)).shaped.<>({r=>import r._; _1.map(_=> CountryRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")

    /** Index over (code) (database name country_code_idx) */
    val index1 = index("country_code_idx", code)
    /** Uniqueness Index over (code) (database name country_code_key) */
    val index2 = index("country_code_key", code, unique=true)
  }
  /** Collection-like TableQuery object for table Country */
  lazy val Country = new TableQuery(tag => new Country(tag))

  /** Entity class storing rows of table CountryRestriction
   *  @param attributeId Database column attribute_id SqlType(int4)
   *  @param countryId Database column country_id SqlType(int4)
   *  @param dc Database column DC SqlType(varchar), Length(10,true) */
  case class CountryRestrictionRow(attributeId: Int, countryId: Int, dc: String)
  /** GetResult implicit for fetching CountryRestrictionRow objects using plain SQL queries */
  implicit def GetResultCountryRestrictionRow(implicit e0: GR[Int], e1: GR[String]): GR[CountryRestrictionRow] = GR{
    prs => import prs._
    CountryRestrictionRow.tupled((<<[Int], <<[Int], <<[String]))
  }
  /** Table description of table country_restriction. Objects of this class serve as prototypes for rows in queries. */
  class CountryRestriction(_tableTag: Tag) extends Table[CountryRestrictionRow](_tableTag, Some("shipping"), "country_restriction") {
    def * = (attributeId, countryId, dc) <> (CountryRestrictionRow.tupled, CountryRestrictionRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(attributeId), Rep.Some(countryId), Rep.Some(dc)).shaped.<>({r=>import r._; _1.map(_=> CountryRestrictionRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column attribute_id SqlType(int4) */
    val attributeId: Rep[Int] = column[Int]("attribute_id")
    /** Database column country_id SqlType(int4) */
    val countryId: Rep[Int] = column[Int]("country_id")
    /** Database column DC SqlType(varchar), Length(10,true) */
    val dc: Rep[String] = column[String]("DC", O.Length(10,varying=true))

    /** Primary key of CountryRestriction (database name country_restriction_pkey) */
    val pk = primaryKey("country_restriction_pkey", (attributeId, countryId, dc))

    /** Foreign key referencing Attribute (database name country_restriction_attribute_id_fkey) */
    lazy val attributeFk = foreignKey("country_restriction_attribute_id_fkey", attributeId, Attribute)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Country (database name country_restriction_country_id_fkey) */
    lazy val countryFk = foreignKey("country_restriction_country_id_fkey", countryId, Country)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Dc (database name country_restriction_DC_fkey) */
    lazy val dcFk = foreignKey("country_restriction_DC_fkey", dc, Dc)(r => r.code, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
  }
  /** Collection-like TableQuery object for table CountryRestriction */
  lazy val CountryRestriction = new TableQuery(tag => new CountryRestriction(tag))

  /** Entity class storing rows of table Currency
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text) */
  case class CurrencyRow(id: Int, name: String, code: String)
  /** GetResult implicit for fetching CurrencyRow objects using plain SQL queries */
  implicit def GetResultCurrencyRow(implicit e0: GR[Int], e1: GR[String]): GR[CurrencyRow] = GR{
    prs => import prs._
    CurrencyRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table currency. Objects of this class serve as prototypes for rows in queries. */
  class Currency(_tableTag: Tag) extends Table[CurrencyRow](_tableTag, "currency") {
    def * = (id, name, code) <> (CurrencyRow.tupled, CurrencyRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code)).shaped.<>({r=>import r._; _1.map(_=> CurrencyRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")

    /** Uniqueness Index over (code) (database name currency_code_key) */
    val index1 = index("currency_code_key", code, unique=true)
  }
  /** Collection-like TableQuery object for table Currency */
  lazy val Currency = new TableQuery(tag => new Currency(tag))

  /** Entity class storing rows of table CustomerSelectableTimezone
   *  @param id Database column id SqlType(int4), PrimaryKey
   *  @param code Database column code SqlType(text)
   *  @param description Database column description SqlType(text) */
  case class CustomerSelectableTimezoneRow(id: Int, code: String, description: String)
  /** GetResult implicit for fetching CustomerSelectableTimezoneRow objects using plain SQL queries */
  implicit def GetResultCustomerSelectableTimezoneRow(implicit e0: GR[Int], e1: GR[String]): GR[CustomerSelectableTimezoneRow] = GR{
    prs => import prs._
    CustomerSelectableTimezoneRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table customer_selectable_timezone. Objects of this class serve as prototypes for rows in queries. */
  class CustomerSelectableTimezone(_tableTag: Tag) extends Table[CustomerSelectableTimezoneRow](_tableTag, Some("shipping"), "customer_selectable_timezone") {
    def * = (id, code, description) <> (CustomerSelectableTimezoneRow.tupled, CustomerSelectableTimezoneRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(code), Rep.Some(description)).shaped.<>({r=>import r._; _1.map(_=> CustomerSelectableTimezoneRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(int4), PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.PrimaryKey)
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")
    /** Database column description SqlType(text) */
    val description: Rep[String] = column[String]("description")
  }
  /** Collection-like TableQuery object for table CustomerSelectableTimezone */
  lazy val CustomerSelectableTimezone = new TableQuery(tag => new CustomerSelectableTimezone(tag))

  /** Entity class storing rows of table Dc
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param code Database column code SqlType(varchar), Length(10,true)
   *  @param name Database column name SqlType(text) */
  case class DcRow(id: Int, code: String, name: String)
  /** GetResult implicit for fetching DcRow objects using plain SQL queries */
  implicit def GetResultDcRow(implicit e0: GR[Int], e1: GR[String]): GR[DcRow] = GR{
    prs => import prs._
    DcRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table dc. Objects of this class serve as prototypes for rows in queries. */
  class Dc(_tableTag: Tag) extends Table[DcRow](_tableTag, "dc") {
    def * = (id, code, name) <> (DcRow.tupled, DcRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(code), Rep.Some(name)).shaped.<>({r=>import r._; _1.map(_=> DcRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column code SqlType(varchar), Length(10,true) */
    val code: Rep[String] = column[String]("code", O.Length(10,varying=true))
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")

    /** Uniqueness Index over (code) (database name dc_code_uindex) */
    val index1 = index("dc_code_uindex", code, unique=true)
  }
  /** Collection-like TableQuery object for table Dc */
  lazy val Dc = new TableQuery(tag => new Dc(tag))

  /** Entity class storing rows of table Description
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param localeId Database column locale_id SqlType(int4)
   *  @param shippingAvailabilityId Database column shipping_availability_id SqlType(int4)
   *  @param name Database column name SqlType(text)
   *  @param title Database column title SqlType(text)
   *  @param publicName Database column public_name SqlType(text)
   *  @param publicTitle Database column public_title SqlType(text)
   *  @param shortDeliveryDescription Database column short_delivery_description SqlType(text), Default(None)
   *  @param longDeliveryDescription Database column long_delivery_description SqlType(text), Default(None)
   *  @param estimatedDelivery Database column estimated_delivery SqlType(text), Default(None)
   *  @param deliveryConfirmation Database column delivery_confirmation SqlType(text), Default(None)
   *  @param cutOffWeekday Database column cut_off_weekday SqlType(text)
   *  @param cutOffWeekend Database column cut_off_weekend SqlType(text) */
  case class DescriptionRow(id: Int, localeId: Int, shippingAvailabilityId: Int, name: String, title: String, publicName: String, publicTitle: String, shortDeliveryDescription: Option[String] = None, longDeliveryDescription: Option[String] = None, estimatedDelivery: Option[String] = None, deliveryConfirmation: Option[String] = None, cutOffWeekday: String, cutOffWeekend: String)
  /** GetResult implicit for fetching DescriptionRow objects using plain SQL queries */
  implicit def GetResultDescriptionRow(implicit e0: GR[Int], e1: GR[String], e2: GR[Option[String]]): GR[DescriptionRow] = GR{
    prs => import prs._
    DescriptionRow.tupled((<<[Int], <<[Int], <<[Int], <<[String], <<[String], <<[String], <<[String], <<?[String], <<?[String], <<?[String], <<?[String], <<[String], <<[String]))
  }
  /** Table description of table description. Objects of this class serve as prototypes for rows in queries. */
  class Description(_tableTag: Tag) extends Table[DescriptionRow](_tableTag, Some("shipping"), "description") {
    def * = (id, localeId, shippingAvailabilityId, name, title, publicName, publicTitle, shortDeliveryDescription, longDeliveryDescription, estimatedDelivery, deliveryConfirmation, cutOffWeekday, cutOffWeekend) <> (DescriptionRow.tupled, DescriptionRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(localeId), Rep.Some(shippingAvailabilityId), Rep.Some(name), Rep.Some(title), Rep.Some(publicName), Rep.Some(publicTitle), shortDeliveryDescription, longDeliveryDescription, estimatedDelivery, deliveryConfirmation, Rep.Some(cutOffWeekday), Rep.Some(cutOffWeekend)).shaped.<>({r=>import r._; _1.map(_=> DescriptionRow.tupled((_1.get, _2.get, _3.get, _4.get, _5.get, _6.get, _7.get, _8, _9, _10, _11, _12.get, _13.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column locale_id SqlType(int4) */
    val localeId: Rep[Int] = column[Int]("locale_id")
    /** Database column shipping_availability_id SqlType(int4) */
    val shippingAvailabilityId: Rep[Int] = column[Int]("shipping_availability_id")
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column title SqlType(text) */
    val title: Rep[String] = column[String]("title")
    /** Database column public_name SqlType(text) */
    val publicName: Rep[String] = column[String]("public_name")
    /** Database column public_title SqlType(text) */
    val publicTitle: Rep[String] = column[String]("public_title")
    /** Database column short_delivery_description SqlType(text), Default(None) */
    val shortDeliveryDescription: Rep[Option[String]] = column[Option[String]]("short_delivery_description", O.Default(None))
    /** Database column long_delivery_description SqlType(text), Default(None) */
    val longDeliveryDescription: Rep[Option[String]] = column[Option[String]]("long_delivery_description", O.Default(None))
    /** Database column estimated_delivery SqlType(text), Default(None) */
    val estimatedDelivery: Rep[Option[String]] = column[Option[String]]("estimated_delivery", O.Default(None))
    /** Database column delivery_confirmation SqlType(text), Default(None) */
    val deliveryConfirmation: Rep[Option[String]] = column[Option[String]]("delivery_confirmation", O.Default(None))
    /** Database column cut_off_weekday SqlType(text) */
    val cutOffWeekday: Rep[String] = column[String]("cut_off_weekday")
    /** Database column cut_off_weekend SqlType(text) */
    val cutOffWeekend: Rep[String] = column[String]("cut_off_weekend")

    /** Foreign key referencing Availability (database name description_shipping_availability_id_fkey) */
    lazy val availabilityFk = foreignKey("description_shipping_availability_id_fkey", shippingAvailabilityId, Availability)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Locale (database name description_locale_id_fkey) */
    lazy val localeFk = foreignKey("description_locale_id_fkey", localeId, Locale)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)

    /** Uniqueness Index over (localeId,shippingAvailabilityId) (database name description_locale_id_shipping_availability_id_key) */
    val index1 = index("description_locale_id_shipping_availability_id_key", (localeId, shippingAvailabilityId), unique=true)
  }
  /** Collection-like TableQuery object for table Description */
  lazy val Description = new TableQuery(tag => new Description(tag))

  /** Entity class storing rows of table Division
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text)
   *  @param countryId Database column country_id SqlType(int4) */
  case class DivisionRow(id: Int, name: String, code: String, countryId: Int)
  /** GetResult implicit for fetching DivisionRow objects using plain SQL queries */
  implicit def GetResultDivisionRow(implicit e0: GR[Int], e1: GR[String]): GR[DivisionRow] = GR{
    prs => import prs._
    DivisionRow.tupled((<<[Int], <<[String], <<[String], <<[Int]))
  }
  /** Table description of table division. Objects of this class serve as prototypes for rows in queries. */
  class Division(_tableTag: Tag) extends Table[DivisionRow](_tableTag, "division") {
    def * = (id, name, code, countryId) <> (DivisionRow.tupled, DivisionRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code), Rep.Some(countryId)).shaped.<>({r=>import r._; _1.map(_=> DivisionRow.tupled((_1.get, _2.get, _3.get, _4.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")
    /** Database column country_id SqlType(int4) */
    val countryId: Rep[Int] = column[Int]("country_id")

    /** Foreign key referencing Country (database name division_country_id_fkey) */
    lazy val countryFk = foreignKey("division_country_id_fkey", countryId, Country)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)

    /** Uniqueness Index over (code,countryId) (database name division_code_country_id_key) */
    val index1 = index("division_code_country_id_key", (code, countryId), unique=true)
    /** Index over (code) (database name division_code_idx) */
    val index2 = index("division_code_idx", code)
  }
  /** Collection-like TableQuery object for table Division */
  lazy val Division = new TableQuery(tag => new Division(tag))

  /** Entity class storing rows of table DivisionRestriction
   *  @param attributeId Database column attribute_id SqlType(int4)
   *  @param divisionId Database column division_id SqlType(int4)
   *  @param dc Database column DC SqlType(varchar), Length(10,true) */
  case class DivisionRestrictionRow(attributeId: Int, divisionId: Int, dc: String)
  /** GetResult implicit for fetching DivisionRestrictionRow objects using plain SQL queries */
  implicit def GetResultDivisionRestrictionRow(implicit e0: GR[Int], e1: GR[String]): GR[DivisionRestrictionRow] = GR{
    prs => import prs._
    DivisionRestrictionRow.tupled((<<[Int], <<[Int], <<[String]))
  }
  /** Table description of table division_restriction. Objects of this class serve as prototypes for rows in queries. */
  class DivisionRestriction(_tableTag: Tag) extends Table[DivisionRestrictionRow](_tableTag, Some("shipping"), "division_restriction") {
    def * = (attributeId, divisionId, dc) <> (DivisionRestrictionRow.tupled, DivisionRestrictionRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(attributeId), Rep.Some(divisionId), Rep.Some(dc)).shaped.<>({r=>import r._; _1.map(_=> DivisionRestrictionRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column attribute_id SqlType(int4) */
    val attributeId: Rep[Int] = column[Int]("attribute_id")
    /** Database column division_id SqlType(int4) */
    val divisionId: Rep[Int] = column[Int]("division_id")
    /** Database column DC SqlType(varchar), Length(10,true) */
    val dc: Rep[String] = column[String]("DC", O.Length(10,varying=true))

    /** Primary key of DivisionRestriction (database name division_restriction_pkey) */
    val pk = primaryKey("division_restriction_pkey", (attributeId, divisionId, dc))

    /** Foreign key referencing Attribute (database name division_restriction_attribute_id_fkey) */
    lazy val attributeFk = foreignKey("division_restriction_attribute_id_fkey", attributeId, Attribute)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Dc (database name division_restriction_DC_fkey) */
    lazy val dcFk = foreignKey("division_restriction_DC_fkey", dc, Dc)(r => r.code, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Division (database name division_restriction_division_id_fkey) */
    lazy val divisionFk = foreignKey("division_restriction_division_id_fkey", divisionId, Division)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
  }
  /** Collection-like TableQuery object for table DivisionRestriction */
  lazy val DivisionRestriction = new TableQuery(tag => new DivisionRestriction(tag))

  /** Entity class storing rows of table Event
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param carrierId Database column carrier_id SqlType(int4)
   *  @param orderNumber Database column order_number SqlType(text)
   *  @param waybillNumber Database column waybill_number SqlType(text)
   *  @param deliveryEventTypeId Database column delivery_event_type_id SqlType(int4)
   *  @param createdAt Database column created_at SqlType(timestamptz)
   *  @param broadcastAt Database column broadcast_at SqlType(timestamptz), Default(None)
   *  @param eventHappenedAt Database column event_happened_at SqlType(timestamptz) */
  case class EventRow(id: Int, carrierId: Int, orderNumber: String, waybillNumber: String, deliveryEventTypeId: Int, createdAt: java.sql.Timestamp, broadcastAt: Option[java.sql.Timestamp] = None, eventHappenedAt: java.sql.Timestamp)
  /** GetResult implicit for fetching EventRow objects using plain SQL queries */
  implicit def GetResultEventRow(implicit e0: GR[Int], e1: GR[String], e2: GR[java.sql.Timestamp], e3: GR[Option[java.sql.Timestamp]]): GR[EventRow] = GR{
    prs => import prs._
    EventRow.tupled((<<[Int], <<[Int], <<[String], <<[String], <<[Int], <<[java.sql.Timestamp], <<?[java.sql.Timestamp], <<[java.sql.Timestamp]))
  }
  /** Table description of table event. Objects of this class serve as prototypes for rows in queries. */
  class Event(_tableTag: Tag) extends Table[EventRow](_tableTag, Some("delivery"), "event") {
    def * = (id, carrierId, orderNumber, waybillNumber, deliveryEventTypeId, createdAt, broadcastAt, eventHappenedAt) <> (EventRow.tupled, EventRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(carrierId), Rep.Some(orderNumber), Rep.Some(waybillNumber), Rep.Some(deliveryEventTypeId), Rep.Some(createdAt), broadcastAt, Rep.Some(eventHappenedAt)).shaped.<>({r=>import r._; _1.map(_=> EventRow.tupled((_1.get, _2.get, _3.get, _4.get, _5.get, _6.get, _7, _8.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column carrier_id SqlType(int4) */
    val carrierId: Rep[Int] = column[Int]("carrier_id")
    /** Database column order_number SqlType(text) */
    val orderNumber: Rep[String] = column[String]("order_number")
    /** Database column waybill_number SqlType(text) */
    val waybillNumber: Rep[String] = column[String]("waybill_number")
    /** Database column delivery_event_type_id SqlType(int4) */
    val deliveryEventTypeId: Rep[Int] = column[Int]("delivery_event_type_id")
    /** Database column created_at SqlType(timestamptz) */
    val createdAt: Rep[java.sql.Timestamp] = column[java.sql.Timestamp]("created_at")
    /** Database column broadcast_at SqlType(timestamptz), Default(None) */
    val broadcastAt: Rep[Option[java.sql.Timestamp]] = column[Option[java.sql.Timestamp]]("broadcast_at", O.Default(None))
    /** Database column event_happened_at SqlType(timestamptz) */
    val eventHappenedAt: Rep[java.sql.Timestamp] = column[java.sql.Timestamp]("event_happened_at")

    /** Foreign key referencing Carrier (database name event_carrier_id_fkey) */
    lazy val carrierFk = foreignKey("event_carrier_id_fkey", carrierId, Carrier)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing EventType (database name event_delivery_event_type_id_fkey) */
    lazy val eventTypeFk = foreignKey("event_delivery_event_type_id_fkey", deliveryEventTypeId, EventType)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
  }
  /** Collection-like TableQuery object for table Event */
  lazy val Event = new TableQuery(tag => new Event(tag))

  /** Entity class storing rows of table EventType
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text) */
  case class EventTypeRow(id: Int, name: String, code: String)
  /** GetResult implicit for fetching EventTypeRow objects using plain SQL queries */
  implicit def GetResultEventTypeRow(implicit e0: GR[Int], e1: GR[String]): GR[EventTypeRow] = GR{
    prs => import prs._
    EventTypeRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table event_type. Objects of this class serve as prototypes for rows in queries. */
  class EventType(_tableTag: Tag) extends Table[EventTypeRow](_tableTag, Some("delivery"), "event_type") {
    def * = (id, name, code) <> (EventTypeRow.tupled, EventTypeRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code)).shaped.<>({r=>import r._; _1.map(_=> EventTypeRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")

    /** Uniqueness Index over (code) (database name event_type_code_key) */
    val index1 = index("event_type_code_key", code, unique=true)
    /** Uniqueness Index over (name) (database name event_type_name_key) */
    val index2 = index("event_type_name_key", name, unique=true)
  }
  /** Collection-like TableQuery object for table EventType */
  lazy val EventType = new TableQuery(tag => new EventType(tag))

  /** Entity class storing rows of table File
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param carrierId Database column carrier_id SqlType(int4)
   *  @param filename Database column filename SqlType(text)
   *  @param remoteModificationEpoch Database column remote_modification_epoch SqlType(int4)
   *  @param numberOfFailures Database column number_of_failures SqlType(int4), Default(0)
   *  @param createdAt Database column created_at SqlType(timestamptz)
   *  @param lastUpdatedAt Database column last_updated_at SqlType(timestamptz)
   *  @param processedAt Database column processed_at SqlType(timestamptz), Default(None) */
  case class FileRow(id: Int, carrierId: Int, filename: String, remoteModificationEpoch: Int, numberOfFailures: Int = 0, createdAt: java.sql.Timestamp, lastUpdatedAt: java.sql.Timestamp, processedAt: Option[java.sql.Timestamp] = None)
  /** GetResult implicit for fetching FileRow objects using plain SQL queries */
  implicit def GetResultFileRow(implicit e0: GR[Int], e1: GR[String], e2: GR[java.sql.Timestamp], e3: GR[Option[java.sql.Timestamp]]): GR[FileRow] = GR{
    prs => import prs._
    FileRow.tupled((<<[Int], <<[Int], <<[String], <<[Int], <<[Int], <<[java.sql.Timestamp], <<[java.sql.Timestamp], <<?[java.sql.Timestamp]))
  }
  /** Table description of table file. Objects of this class serve as prototypes for rows in queries. */
  class File(_tableTag: Tag) extends Table[FileRow](_tableTag, Some("delivery"), "file") {
    def * = (id, carrierId, filename, remoteModificationEpoch, numberOfFailures, createdAt, lastUpdatedAt, processedAt) <> (FileRow.tupled, FileRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(carrierId), Rep.Some(filename), Rep.Some(remoteModificationEpoch), Rep.Some(numberOfFailures), Rep.Some(createdAt), Rep.Some(lastUpdatedAt), processedAt).shaped.<>({r=>import r._; _1.map(_=> FileRow.tupled((_1.get, _2.get, _3.get, _4.get, _5.get, _6.get, _7.get, _8)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column carrier_id SqlType(int4) */
    val carrierId: Rep[Int] = column[Int]("carrier_id")
    /** Database column filename SqlType(text) */
    val filename: Rep[String] = column[String]("filename")
    /** Database column remote_modification_epoch SqlType(int4) */
    val remoteModificationEpoch: Rep[Int] = column[Int]("remote_modification_epoch")
    /** Database column number_of_failures SqlType(int4), Default(0) */
    val numberOfFailures: Rep[Int] = column[Int]("number_of_failures", O.Default(0))
    /** Database column created_at SqlType(timestamptz) */
    val createdAt: Rep[java.sql.Timestamp] = column[java.sql.Timestamp]("created_at")
    /** Database column last_updated_at SqlType(timestamptz) */
    val lastUpdatedAt: Rep[java.sql.Timestamp] = column[java.sql.Timestamp]("last_updated_at")
    /** Database column processed_at SqlType(timestamptz), Default(None) */
    val processedAt: Rep[Option[java.sql.Timestamp]] = column[Option[java.sql.Timestamp]]("processed_at", O.Default(None))

    /** Foreign key referencing Carrier (database name file_carrier_id_fkey) */
    lazy val carrierFk = foreignKey("file_carrier_id_fkey", carrierId, Carrier)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)

    /** Uniqueness Index over (filename) (database name file_filename_key) */
    val index1 = index("file_filename_key", filename, unique=true)
  }
  /** Collection-like TableQuery object for table File */
  lazy val File = new TableQuery(tag => new File(tag))

  /** Entity class storing rows of table Language
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param code Database column code SqlType(text)
   *  @param description Database column description SqlType(text) */
  case class LanguageRow(id: Int, code: String, description: String)
  /** GetResult implicit for fetching LanguageRow objects using plain SQL queries */
  implicit def GetResultLanguageRow(implicit e0: GR[Int], e1: GR[String]): GR[LanguageRow] = GR{
    prs => import prs._
    LanguageRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table language. Objects of this class serve as prototypes for rows in queries. */
  class Language(_tableTag: Tag) extends Table[LanguageRow](_tableTag, "language") {
    def * = (id, code, description) <> (LanguageRow.tupled, LanguageRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(code), Rep.Some(description)).shaped.<>({r=>import r._; _1.map(_=> LanguageRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")
    /** Database column description SqlType(text) */
    val description: Rep[String] = column[String]("description")

    /** Uniqueness Index over (code) (database name language_code_key) */
    val index1 = index("language_code_key", code, unique=true)
    /** Uniqueness Index over (description) (database name language_description_key) */
    val index2 = index("language_description_key", description, unique=true)
  }
  /** Collection-like TableQuery object for table Language */
  lazy val Language = new TableQuery(tag => new Language(tag))

  /** Entity class storing rows of table Locale
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param countryId Database column country_id SqlType(int4)
   *  @param languageId Database column language_id SqlType(int4) */
  case class LocaleRow(id: Int, countryId: Int, languageId: Int)
  /** GetResult implicit for fetching LocaleRow objects using plain SQL queries */
  implicit def GetResultLocaleRow(implicit e0: GR[Int]): GR[LocaleRow] = GR{
    prs => import prs._
    LocaleRow.tupled((<<[Int], <<[Int], <<[Int]))
  }
  /** Table description of table locale. Objects of this class serve as prototypes for rows in queries. */
  class Locale(_tableTag: Tag) extends Table[LocaleRow](_tableTag, "locale") {
    def * = (id, countryId, languageId) <> (LocaleRow.tupled, LocaleRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(countryId), Rep.Some(languageId)).shaped.<>({r=>import r._; _1.map(_=> LocaleRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column country_id SqlType(int4) */
    val countryId: Rep[Int] = column[Int]("country_id")
    /** Database column language_id SqlType(int4) */
    val languageId: Rep[Int] = column[Int]("language_id")

    /** Foreign key referencing Country (database name locale_country_id_fkey) */
    lazy val countryFk = foreignKey("locale_country_id_fkey", countryId, Country)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Language (database name locale_language_id_fkey) */
    lazy val languageFk = foreignKey("locale_language_id_fkey", languageId, Language)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)

    /** Uniqueness Index over (countryId,languageId) (database name locale_country_id_language_id_key) */
    val index1 = index("locale_country_id_language_id_key", (countryId, languageId), unique=true)
  }
  /** Collection-like TableQuery object for table Locale */
  lazy val Locale = new TableQuery(tag => new Locale(tag))

  /** Entity class storing rows of table PackagingGroup
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text) */
  case class PackagingGroupRow(id: Int, name: String, code: String)
  /** GetResult implicit for fetching PackagingGroupRow objects using plain SQL queries */
  implicit def GetResultPackagingGroupRow(implicit e0: GR[Int], e1: GR[String]): GR[PackagingGroupRow] = GR{
    prs => import prs._
    PackagingGroupRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table packaging_group. Objects of this class serve as prototypes for rows in queries. */
  class PackagingGroup(_tableTag: Tag) extends Table[PackagingGroupRow](_tableTag, Some("shipping"), "packaging_group") {
    def * = (id, name, code) <> (PackagingGroupRow.tupled, PackagingGroupRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code)).shaped.<>({r=>import r._; _1.map(_=> PackagingGroupRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")

    /** Uniqueness Index over (code) (database name packaging_group_code_key) */
    val index1 = index("packaging_group_code_key", code, unique=true)
    /** Uniqueness Index over (name) (database name packaging_group_name_key) */
    val index2 = index("packaging_group_name_key", name, unique=true)
  }
  /** Collection-like TableQuery object for table PackagingGroup */
  lazy val PackagingGroup = new TableQuery(tag => new PackagingGroup(tag))

  /** Entity class storing rows of table PostCode
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param code Database column code SqlType(text)
   *  @param countryId Database column country_id SqlType(int4) */
  case class PostCodeRow(id: Int, code: String, countryId: Int)
  /** GetResult implicit for fetching PostCodeRow objects using plain SQL queries */
  implicit def GetResultPostCodeRow(implicit e0: GR[Int], e1: GR[String]): GR[PostCodeRow] = GR{
    prs => import prs._
    PostCodeRow.tupled((<<[Int], <<[String], <<[Int]))
  }
  /** Table description of table post_code. Objects of this class serve as prototypes for rows in queries. */
  class PostCode(_tableTag: Tag) extends Table[PostCodeRow](_tableTag, "post_code") {
    def * = (id, code, countryId) <> (PostCodeRow.tupled, PostCodeRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(code), Rep.Some(countryId)).shaped.<>({r=>import r._; _1.map(_=> PostCodeRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")
    /** Database column country_id SqlType(int4) */
    val countryId: Rep[Int] = column[Int]("country_id")

    /** Foreign key referencing Country (database name post_code_country_id_fkey) */
    lazy val countryFk = foreignKey("post_code_country_id_fkey", countryId, Country)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)

    /** Uniqueness Index over (code,countryId) (database name post_code_code_country_id_key) */
    val index1 = index("post_code_code_country_id_key", (code, countryId), unique=true)
  }
  /** Collection-like TableQuery object for table PostCode */
  lazy val PostCode = new TableQuery(tag => new PostCode(tag))

  /** Entity class storing rows of table PostCodeGroup
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text) */
  case class PostCodeGroupRow(id: Int, name: String, code: String)
  /** GetResult implicit for fetching PostCodeGroupRow objects using plain SQL queries */
  implicit def GetResultPostCodeGroupRow(implicit e0: GR[Int], e1: GR[String]): GR[PostCodeGroupRow] = GR{
    prs => import prs._
    PostCodeGroupRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table post_code_group. Objects of this class serve as prototypes for rows in queries. */
  class PostCodeGroup(_tableTag: Tag) extends Table[PostCodeGroupRow](_tableTag, "post_code_group") {
    def * = (id, name, code) <> (PostCodeGroupRow.tupled, PostCodeGroupRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code)).shaped.<>({r=>import r._; _1.map(_=> PostCodeGroupRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")

    /** Uniqueness Index over (code) (database name post_code_group_code_key) */
    val index1 = index("post_code_group_code_key", code, unique=true)
  }
  /** Collection-like TableQuery object for table PostCodeGroup */
  lazy val PostCodeGroup = new TableQuery(tag => new PostCodeGroup(tag))

  /** Entity class storing rows of table PostCodeGroupMember
   *  @param postCodeGroupId Database column post_code_group_id SqlType(int4)
   *  @param postCodeId Database column post_code_id SqlType(int4) */
  case class PostCodeGroupMemberRow(postCodeGroupId: Int, postCodeId: Int)
  /** GetResult implicit for fetching PostCodeGroupMemberRow objects using plain SQL queries */
  implicit def GetResultPostCodeGroupMemberRow(implicit e0: GR[Int]): GR[PostCodeGroupMemberRow] = GR{
    prs => import prs._
    PostCodeGroupMemberRow.tupled((<<[Int], <<[Int]))
  }
  /** Table description of table post_code_group_member. Objects of this class serve as prototypes for rows in queries. */
  class PostCodeGroupMember(_tableTag: Tag) extends Table[PostCodeGroupMemberRow](_tableTag, "post_code_group_member") {
    def * = (postCodeGroupId, postCodeId) <> (PostCodeGroupMemberRow.tupled, PostCodeGroupMemberRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(postCodeGroupId), Rep.Some(postCodeId)).shaped.<>({r=>import r._; _1.map(_=> PostCodeGroupMemberRow.tupled((_1.get, _2.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column post_code_group_id SqlType(int4) */
    val postCodeGroupId: Rep[Int] = column[Int]("post_code_group_id")
    /** Database column post_code_id SqlType(int4) */
    val postCodeId: Rep[Int] = column[Int]("post_code_id")

    /** Primary key of PostCodeGroupMember (database name post_code_group_member_pkey) */
    val pk = primaryKey("post_code_group_member_pkey", (postCodeGroupId, postCodeId))

    /** Foreign key referencing PostCode (database name post_code_group_member_post_code_id_fkey) */
    lazy val postCodeFk = foreignKey("post_code_group_member_post_code_id_fkey", postCodeId, PostCode)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing PostCodeGroup (database name post_code_group_member_post_code_group_id_fkey) */
    lazy val postCodeGroupFk = foreignKey("post_code_group_member_post_code_group_id_fkey", postCodeGroupId, PostCodeGroup)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
  }
  /** Collection-like TableQuery object for table PostCodeGroupMember */
  lazy val PostCodeGroupMember = new TableQuery(tag => new PostCodeGroupMember(tag))

  /** Entity class storing rows of table PostCodeRestriction
   *  @param attributeId Database column attribute_id SqlType(int4)
   *  @param postCodeGroupId Database column post_code_group_id SqlType(int4)
   *  @param dc Database column DC SqlType(varchar), Length(10,true) */
  case class PostCodeRestrictionRow(attributeId: Int, postCodeGroupId: Int, dc: String)
  /** GetResult implicit for fetching PostCodeRestrictionRow objects using plain SQL queries */
  implicit def GetResultPostCodeRestrictionRow(implicit e0: GR[Int], e1: GR[String]): GR[PostCodeRestrictionRow] = GR{
    prs => import prs._
    PostCodeRestrictionRow.tupled((<<[Int], <<[Int], <<[String]))
  }
  /** Table description of table post_code_restriction. Objects of this class serve as prototypes for rows in queries. */
  class PostCodeRestriction(_tableTag: Tag) extends Table[PostCodeRestrictionRow](_tableTag, Some("shipping"), "post_code_restriction") {
    def * = (attributeId, postCodeGroupId, dc) <> (PostCodeRestrictionRow.tupled, PostCodeRestrictionRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(attributeId), Rep.Some(postCodeGroupId), Rep.Some(dc)).shaped.<>({r=>import r._; _1.map(_=> PostCodeRestrictionRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column attribute_id SqlType(int4) */
    val attributeId: Rep[Int] = column[Int]("attribute_id")
    /** Database column post_code_group_id SqlType(int4) */
    val postCodeGroupId: Rep[Int] = column[Int]("post_code_group_id")
    /** Database column DC SqlType(varchar), Length(10,true) */
    val dc: Rep[String] = column[String]("DC", O.Length(10,varying=true))

    /** Primary key of PostCodeRestriction (database name post_code_restriction_pkey) */
    val pk = primaryKey("post_code_restriction_pkey", (attributeId, postCodeGroupId, dc))

    /** Foreign key referencing Attribute (database name post_code_restriction_attribute_id_fkey) */
    lazy val attributeFk = foreignKey("post_code_restriction_attribute_id_fkey", attributeId, Attribute)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Dc (database name post_code_restriction_DC_fkey) */
    lazy val dcFk = foreignKey("post_code_restriction_DC_fkey", dc, Dc)(r => r.code, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing PostCodeGroup (database name post_code_restriction_post_code_group_id_fkey) */
    lazy val postCodeGroupFk = foreignKey("post_code_restriction_post_code_group_id_fkey", postCodeGroupId, PostCodeGroup)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
  }
  /** Collection-like TableQuery object for table PostCodeRestriction */
  lazy val PostCodeRestriction = new TableQuery(tag => new PostCodeRestriction(tag))

  /** Entity class storing rows of table PromotionGroup
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text) */
  case class PromotionGroupRow(id: Int, name: String, code: String)
  /** GetResult implicit for fetching PromotionGroupRow objects using plain SQL queries */
  implicit def GetResultPromotionGroupRow(implicit e0: GR[Int], e1: GR[String]): GR[PromotionGroupRow] = GR{
    prs => import prs._
    PromotionGroupRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table promotion_group. Objects of this class serve as prototypes for rows in queries. */
  class PromotionGroup(_tableTag: Tag) extends Table[PromotionGroupRow](_tableTag, Some("shipping"), "promotion_group") {
    def * = (id, name, code) <> (PromotionGroupRow.tupled, PromotionGroupRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code)).shaped.<>({r=>import r._; _1.map(_=> PromotionGroupRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")

    /** Uniqueness Index over (code) (database name promotion_group_code_key) */
    val index1 = index("promotion_group_code_key", code, unique=true)
    /** Uniqueness Index over (name) (database name promotion_group_name_key) */
    val index2 = index("promotion_group_name_key", name, unique=true)
  }
  /** Collection-like TableQuery object for table PromotionGroup */
  lazy val PromotionGroup = new TableQuery(tag => new PromotionGroup(tag))

  /** Entity class storing rows of table Restriction
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param restrictedDate Database column restricted_date SqlType(date)
   *  @param shippingAvailabilityId Database column shipping_availability_id SqlType(int4)
   *  @param isRestricted Database column is_restricted SqlType(bool)
   *  @param stageId Database column stage_id SqlType(int4) */
  case class RestrictionRow(id: Int, restrictedDate: java.sql.Date, shippingAvailabilityId: Int, isRestricted: Boolean, stageId: Int)
  /** GetResult implicit for fetching RestrictionRow objects using plain SQL queries */
  implicit def GetResultRestrictionRow(implicit e0: GR[Int], e1: GR[java.sql.Date], e2: GR[Boolean]): GR[RestrictionRow] = GR{
    prs => import prs._
    RestrictionRow.tupled((<<[Int], <<[java.sql.Date], <<[Int], <<[Boolean], <<[Int]))
  }
  /** Table description of table restriction. Objects of this class serve as prototypes for rows in queries. */
  class Restriction(_tableTag: Tag) extends Table[RestrictionRow](_tableTag, Some("delivery"), "restriction") {
    def * = (id, restrictedDate, shippingAvailabilityId, isRestricted, stageId) <> (RestrictionRow.tupled, RestrictionRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(restrictedDate), Rep.Some(shippingAvailabilityId), Rep.Some(isRestricted), Rep.Some(stageId)).shaped.<>({r=>import r._; _1.map(_=> RestrictionRow.tupled((_1.get, _2.get, _3.get, _4.get, _5.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column restricted_date SqlType(date) */
    val restrictedDate: Rep[java.sql.Date] = column[java.sql.Date]("restricted_date")
    /** Database column shipping_availability_id SqlType(int4) */
    val shippingAvailabilityId: Rep[Int] = column[Int]("shipping_availability_id")
    /** Database column is_restricted SqlType(bool) */
    val isRestricted: Rep[Boolean] = column[Boolean]("is_restricted")
    /** Database column stage_id SqlType(int4) */
    val stageId: Rep[Int] = column[Int]("stage_id")

    /** Foreign key referencing Availability (database name restriction_shipping_availability_id_fkey) */
    lazy val availabilityFk = foreignKey("restriction_shipping_availability_id_fkey", shippingAvailabilityId, Availability)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Stage (database name restriction_stage_id_fkey) */
    lazy val stageFk = foreignKey("restriction_stage_id_fkey", stageId, Stage)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)

    /** Uniqueness Index over (restrictedDate,shippingAvailabilityId,stageId) (database name restriction_restricted_date_shipping_availability_id_stage__key) */
    val index1 = index("restriction_restricted_date_shipping_availability_id_stage__key", (restrictedDate, shippingAvailabilityId, stageId), unique=true)
  }
  /** Collection-like TableQuery object for table Restriction */
  lazy val Restriction = new TableQuery(tag => new Restriction(tag))

  /** Entity class storing rows of table ShippingOption
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text)
   *  @param isLimitedAvailability Database column is_limited_availability SqlType(bool), Default(false) */
  case class OptionRow(id: Int, name: String, code: String, isLimitedAvailability: Boolean = false)
  /** GetResult implicit for fetching OptionRow objects using plain SQL queries */
  implicit def GetResultOptionRow(implicit e0: GR[Int], e1: GR[String], e2: GR[Boolean]): GR[OptionRow] = GR{
    prs => import prs._
    OptionRow.tupled((<<[Int], <<[String], <<[String], <<[Boolean]))
  }
  /** Table description of table option. Objects of this class serve as prototypes for rows in queries. */
  class ShippingOption(_tableTag: Tag) extends Table[OptionRow](_tableTag, Some("shipping"), "option") {
    def * = (id, name, code, isLimitedAvailability) <> (OptionRow.tupled, OptionRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code), Rep.Some(isLimitedAvailability)).shaped.<>({r=>import r._; _1.map(_=> OptionRow.tupled((_1.get, _2.get, _3.get, _4.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")
    /** Database column is_limited_availability SqlType(bool), Default(false) */
    val isLimitedAvailability: Rep[Boolean] = column[Boolean]("is_limited_availability", O.Default(false))

    /** Uniqueness Index over (code) (database name option_code_key) */
    val index1 = index("option_code_key", code, unique=true)
    /** Uniqueness Index over (name) (database name option_name_key) */
    val index2 = index("option_name_key", name, unique=true)
  }
  /** Collection-like TableQuery object for table ShippingOption */
  lazy val ShippingOption = new TableQuery(tag => new ShippingOption(tag))

  /** Entity class storing rows of table SignatureRequiredStatus
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text) */
  case class SignatureRequiredStatusRow(id: Int, name: String, code: String)
  /** GetResult implicit for fetching SignatureRequiredStatusRow objects using plain SQL queries */
  implicit def GetResultSignatureRequiredStatusRow(implicit e0: GR[Int], e1: GR[String]): GR[SignatureRequiredStatusRow] = GR{
    prs => import prs._
    SignatureRequiredStatusRow.tupled((<<[Int], <<[String], <<[String]))
  }
  /** Table description of table signature_required_status. Objects of this class serve as prototypes for rows in queries. */
  class SignatureRequiredStatus(_tableTag: Tag) extends Table[SignatureRequiredStatusRow](_tableTag, Some("shipping"), "signature_required_status") {
    def * = (id, name, code) <> (SignatureRequiredStatusRow.tupled, SignatureRequiredStatusRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code)).shaped.<>({r=>import r._; _1.map(_=> SignatureRequiredStatusRow.tupled((_1.get, _2.get, _3.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")

    /** Uniqueness Index over (code) (database name signature_required_status_code_key) */
    val index1 = index("signature_required_status_code_key", code, unique=true)
    /** Uniqueness Index over (name) (database name signature_required_status_name_key) */
    val index2 = index("signature_required_status_name_key", name, unique=true)
  }
  /** Collection-like TableQuery object for table SignatureRequiredStatus */
  lazy val SignatureRequiredStatus = new TableQuery(tag => new SignatureRequiredStatus(tag))

  /** Entity class storing rows of table Stage
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param name Database column name SqlType(text)
   *  @param code Database column code SqlType(text)
   *  @param ranking Database column ranking SqlType(int4) */
  case class StageRow(id: Int, name: String, code: String, ranking: Int)
  /** GetResult implicit for fetching StageRow objects using plain SQL queries */
  implicit def GetResultStageRow(implicit e0: GR[Int], e1: GR[String]): GR[StageRow] = GR{
    prs => import prs._
    StageRow.tupled((<<[Int], <<[String], <<[String], <<[Int]))
  }
  /** Table description of table stage. Objects of this class serve as prototypes for rows in queries. */
  class Stage(_tableTag: Tag) extends Table[StageRow](_tableTag, Some("delivery"), "stage") {
    def * = (id, name, code, ranking) <> (StageRow.tupled, StageRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(name), Rep.Some(code), Rep.Some(ranking)).shaped.<>({r=>import r._; _1.map(_=> StageRow.tupled((_1.get, _2.get, _3.get, _4.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column name SqlType(text) */
    val name: Rep[String] = column[String]("name")
    /** Database column code SqlType(text) */
    val code: Rep[String] = column[String]("code")
    /** Database column ranking SqlType(int4) */
    val ranking: Rep[Int] = column[Int]("ranking")

    /** Uniqueness Index over (code) (database name stage_code_key) */
    val index1 = index("stage_code_key", code, unique=true)
    /** Uniqueness Index over (name) (database name stage_name_key) */
    val index2 = index("stage_name_key", name, unique=true)
    /** Uniqueness Index over (ranking) (database name stage_ranking_key) */
    val index3 = index("stage_ranking_key", ranking, unique=true)
  }
  /** Collection-like TableQuery object for table Stage */
  lazy val Stage = new TableQuery(tag => new Stage(tag))

  /** Entity class storing rows of table StageDaysToComplete
   *  @param id Database column id SqlType(serial), AutoInc, PrimaryKey
   *  @param shippingAvailabilityId Database column shipping_availability_id SqlType(int4)
   *  @param stageId Database column stage_id SqlType(int4)
   *  @param daysToComplete Database column days_to_complete SqlType(int4) */
  case class StageDaysToCompleteRow(id: Int, shippingAvailabilityId: Int, stageId: Int, daysToComplete: Int)
  /** GetResult implicit for fetching StageDaysToCompleteRow objects using plain SQL queries */
  implicit def GetResultStageDaysToCompleteRow(implicit e0: GR[Int]): GR[StageDaysToCompleteRow] = GR{
    prs => import prs._
    StageDaysToCompleteRow.tupled((<<[Int], <<[Int], <<[Int], <<[Int]))
  }
  /** Table description of table stage_days_to_complete. Objects of this class serve as prototypes for rows in queries. */
  class StageDaysToComplete(_tableTag: Tag) extends Table[StageDaysToCompleteRow](_tableTag, Some("delivery"), "stage_days_to_complete") {
    def * = (id, shippingAvailabilityId, stageId, daysToComplete) <> (StageDaysToCompleteRow.tupled, StageDaysToCompleteRow.unapply)
    /** Maps whole row to an option. Useful for outer joins. */
    def ? = (Rep.Some(id), Rep.Some(shippingAvailabilityId), Rep.Some(stageId), Rep.Some(daysToComplete)).shaped.<>({r=>import r._; _1.map(_=> StageDaysToCompleteRow.tupled((_1.get, _2.get, _3.get, _4.get)))}, (_:Any) =>  throw new Exception("Inserting into ? projection not supported."))

    /** Database column id SqlType(serial), AutoInc, PrimaryKey */
    val id: Rep[Int] = column[Int]("id", O.AutoInc, O.PrimaryKey)
    /** Database column shipping_availability_id SqlType(int4) */
    val shippingAvailabilityId: Rep[Int] = column[Int]("shipping_availability_id")
    /** Database column stage_id SqlType(int4) */
    val stageId: Rep[Int] = column[Int]("stage_id")
    /** Database column days_to_complete SqlType(int4) */
    val daysToComplete: Rep[Int] = column[Int]("days_to_complete")

    /** Foreign key referencing Availability (database name stage_days_to_complete_shipping_availability_id_fkey) */
    lazy val availabilityFk = foreignKey("stage_days_to_complete_shipping_availability_id_fkey", shippingAvailabilityId, Availability)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
    /** Foreign key referencing Stage (database name stage_days_to_complete_stage_id_fkey) */
    lazy val stageFk = foreignKey("stage_days_to_complete_stage_id_fkey", stageId, Stage)(r => r.id, onUpdate=ForeignKeyAction.NoAction, onDelete=ForeignKeyAction.NoAction)
  }
  /** Collection-like TableQuery object for table StageDaysToComplete */
  lazy val StageDaysToComplete = new TableQuery(tag => new StageDaysToComplete(tag))
}
