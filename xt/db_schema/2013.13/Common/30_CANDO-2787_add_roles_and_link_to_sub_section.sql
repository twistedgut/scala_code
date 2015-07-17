-- CANDO-2787: Adds Roles to 'acl.authorisation_role' table and links them
--             to 'acl.link_authorisation_role__authorisation_sub_section'

BEGIN WORK;

-- create temp table with roles, sections & sub-sections
CREATE TEMP TABLE tmp_roles (
    acl_role        CHARACTER VARYING (255),
    acl_section     CHARACTER VARYING (255),
    acl_sub_section CHARACTER VARYING (255)
);

-- populate the temp table
COPY tmp_roles ( acl_role, acl_section, acl_sub_section ) FROM STDIN WITH DELIMITER ',';
app_canViewCreditHold,Finance,Credit Hold
app_canViewCreditCheck,Finance,Credit Check
app_canProcessInvalidPayments,Finance,Invalid Payments
app_canProcessRefundsDebits,Finance,Active Invoices
app_canViewPendingRefundsDebits,Finance,Pending Invoices
app_canViewFraudHotlist,Finance,Fraud Hotlist
app_canManageFraudRules,Finance,Fraud Rules
app_canManageFraudRuleSettings,Admin,Fraud Rules
app_canViewStoreCredit,Finance,Store Credits
app_canCreateBulkReimbursement,Finance,Reimbursements
app_canRunDatacashReport,Finance,Transaction Reporting
app_canManageNAPEvents,NAP Events,Manage
app_canManageOutnetEvents,Outnet Events,Manage
app_canManageInBoxPromotions,NAP Events,In The Box
app_canManageWelcomePacks,NAP Events,Welcome Packs
app_canSearchOrders,Customer Care,Order Search
app_canAnonymousSearchOrders,Customer Care,Order Search
app_canSearchCustomers,Customer Care,Customer Search
app_canManageCustomerReturns,Customer Care,Returns Pending
app_canViewPendingReturns,Customer Care,Returns Pending
app_canViewProductReservations,Stock Control,Reservation
app_canManageEmailTemplates,Admin,Email Templates
app_canModifyUserAccounts,Admin,User Admin
app_canSetReportingExchangeRates,Admin,Exchange Rates
app_canViewJobQueue,Admin,Job Queue
app_canManagePrinters,Admin,Printers
app_canManageSystemParameters,Admin,System Parameters
app_canProcessDDUOrders,Fulfilment,DDU
app_canHoldShipments,Fulfilment,On Hold
app_canCheckPackingExceptionShipment,Fulfilment,Packing Exception
app_canViewShipmentInSelection,Fulfilment,Selection
app_canViewShipmentInPicking,Fulfilment,Picking
app_canPickShipments,Fulfilment,Picking
app_canViewShipmentsInPacking,Fulfilment,Packing
app_canPackShipments,Fulfilment,Packing
app_canMonitorPackLanes,Fulfilment,Pack Lane Activity
app_canManageComissionerContainers,Fulfilment,Commissioner
app_canInductContainers,Fulfilment,Induction
app_canManuallyProcessShipmentPaperwork,Fulfilment,Airwaybill
app_canProcessShipmentPaperwork,Fulfilment,Labelling
app_canManageInvalidShipmentAddresses,Fulfilment,Invalid Shipments
app_canExportShippingManifest,Fulfilment,Manifest
app_canDispatchShipments,Fulfilment,Dispatch
app_canExportPremierRoutingData,Fulfilment,Premier Routing
app_canDispatchPremierShipments,Fulfilment,Premier Dispatch
app_canGenerateShippingReports,Reporting,Shipping Reports
app_canProcessStockDelivery,Goods In,Stock In
app_canPerformBlindItemCount,Goods In,Item Count
app_canPerformUnrestrictedItemCount,Goods In,Item Count
app_canQualityControlStockDelivery,Goods In,Quality Control
app_canBagTagStockDelivery,Goods In,Bag And Tag
app_canPutawayStockDelivery,Goods In,Putaway
app_canRecordCustomerReturnsArrival,Goods In,Returns Arrival
app_canProcessCustomerReturn,Goods In,Returns In
app_canQualityControlCustomerReturn,Goods In,Returns QC
app_canViewFaultyCustomerReturns,Goods In,Returns Faulty
app_canPrintStockBarcodes,Goods In,Barcode
app_canCancelStockDelivery,Goods In,Delivery Cancel
app_canViewHeldStockDeliveries,Goods In,Delivery Hold
app_canReviewDeliveryTimetable,Goods In,Delivery Timetable
app_canMonitorRecentStockDeliveries,Goods In,Recent Deliveries
app_canProcessSurplusStockDeliveries,Goods In,Surplus
app_canProcessVendorSamplesIntoStock,Goods In,Vendor Sample In
app_canPerformPutawayPreparation,Goods In,Putaway Prep
app_canPerformPutawayAdmin,Goods In,Putaway Prep Admin
app_canResolvePutawayProblems,Goods In,Putaway Problem Resolution
app_canPerformPutawayPreparationException,Goods In,Putaway Prep Packing Exception
app_canRunDistributionReports,Reporting,Distribution Reports
app_canManageDutyRtes,Stock Control,Duty Rates
app_canViewProductInventoryOverview,Stock Control,Inventory
app_canSearchStockLocations,Stock Control,Location
app_canViewProductMeasurements,Stock Control,Measurement
app_canManagePerpetualInventory,Stock Control,Perpetual Inventory
app_canSearchProductPurchaseOrders,Stock Control,Purchase Order
app_canProcessQuarantineStock,Stock Control,Quarantine
app_canCheckProductStockLevels,Stock Control,Stock Check
app_canRelocateStock,Stock Control,Stock Relocation
app_canReviewProductChannelTransfers,Stock Control,Channel Transfer
app_canManageDeadStock,Stock Control,Dead Stock
app_canRecodeStock,Stock Control,Recode
app_canAdjustStockLevels,Stock Control,Stock Adjustment
app_canRunProductApprovalReport,Stock Control,Product Approval
app_canRTVStock,RTV,Faulty GI
app_canRTVStock,RTV,Inspect Pick
app_canRTVStock,RTV,Request RMA
app_canRTVStock,RTV,List RMA
app_canRTVStock,RTV,List RTV
app_canRTVStock,RTV,Pick RTV
app_canRTVStock,RTV,Pack RTV
app_canRTVStock,RTV,Awaiting Dispatch
app_canRTVStock,RTV,Dispatched RTV
app_canRTVStock,RTV,Non Faulty
app_canViewRTVShipments,RTV,List RMA
app_canViewRTVShipments,RTV,List RTV
app_canViewRTVShipments,RTV,Awaiting Dispatch
app_canViewRTVShipments,RTV,Dispatched RTV
app_canRequestReturnSampleTransfers,Stock Control,Sample
app_canReviewSampleTransfers,Stock Control,Sample
app_canAdjustSampleStock,Stock Control,Sample Adjustment
app_canRequestStockFromSampleRoom,Sample,Sample Cart
app_canRequestStockFromSampleRoom,Sample,Review Requests
app_canProcessSampleUploadTransfer,Sample,Sample Transfer
app_canReviewSampleCartUsers,Sample,Sample Cart Users
app_canManageSampleCartUsers,Sample,Sample Cart Users
app_canManageDesignerLandingPages,Web Content,Designer Landing
app_canManageWebsiteContent,Web Content,Magazine
app_canManageStickyPages,Admin,Sticky Pages
\.

--
-- Create the Roles
--
INSERT INTO acl.authorisation_role ( authorisation_role )
SELECT  DISTINCT acl_role
FROM    tmp_roles
;

--
-- Link the Roles to Sub-Sections
--
INSERT INTO acl.link_authorisation_role__authorisation_sub_section ( authorisation_role_id, authorisation_sub_section_id )
SELECT  role.id,
        sub_section.id
FROM    tmp_roles tmpr
            JOIN acl.authorisation_role     role        ON role.authorisation_role              = tmpr.acl_role
            JOIN authorisation_section      section     ON section.section                      = tmpr.acl_section
            JOIN authorisation_sub_section  sub_section ON sub_section.sub_section              = tmpr.acl_sub_section
                                                       AND sub_section.authorisation_section_id = section.id
;

COMMIT WORK;
