begin;

update system_config.config_group set name = case name
	when 'Printer_Station_Returns_In_01' then 'Printer_Station_Sample_Returns_In_01'
	when 'Printer_Station_Returns_In_02' then 'Printer_Station_Customer_Returns_In_01'
	when 'Printer_Station_Returns_QC_01' then 'Printer_Station_Customer_Returns_QC_01'
	when 'Printer_Station_Returns_QC_02' then 'Printer_Station_Customer_Returns_QC_02'
	when 'Printer_Station_Returns_QC_03' then 'Printer_Station_Customer_Returns_QC_03'
	when 'Printer_Station_Returns_QC_04' then 'Printer_Station_Customer_Returns_QC_04'
	when 'Printer_Station_Returns_QC_05' then 'Printer_Station_Customer_Returns_QC_05'
	when 'Printer_Station_Returns_QC_06' then 'Printer_Station_Customer_Returns_QC_06'
	when 'Printer_Station_Returns_QC_07' then 'Printer_Station_Customer_Returns_QC_07'
	when 'Printer_Station_Returns_QC_08' then 'Printer_Station_Customer_Returns_QC_08'
	end
	where name in (	'Printer_Station_Returns_In_01','Printer_Station_Returns_QC_01',
			'Printer_Station_Returns_In_02','Printer_Station_Returns_QC_02',
			'Printer_Station_Returns_QC_03','Printer_Station_Returns_QC_04',
			'Printer_Station_Returns_QC_05','Printer_Station_Returns_QC_06',
			'Printer_Station_Returns_QC_07','Printer_Station_Returns_QC_08');


insert into system_config.config_group (name, active) values
	('Printer_Station_Customer_Returns_In_02', true),
	('Printer_Station_Customer_Returns_In_03', true),
	('Printer_Station_Customer_Returns_In_04', true),
	('Printer_Station_Sample_Returns_QC_01', true);


update system_config.config_group_setting set value = case value
	when 'Printer_Station_Returns_In_01' then 'Printer_Station_Sample_Returns_In_01'
	when 'Printer_Station_Returns_In_02' then 'Printer_Station_Customer_Returns_In_01'
	when 'Printer_Station_Returns_QC_01' then 'Printer_Station_Customer_Returns_QC_01'
	when 'Printer_Station_Returns_QC_02' then 'Printer_Station_Customer_Returns_QC_02'
	when 'Printer_Station_Returns_QC_03' then 'Printer_Station_Customer_Returns_QC_03'
	when 'Printer_Station_Returns_QC_04' then 'Printer_Station_Customer_Returns_QC_04'
	when 'Printer_Station_Returns_QC_05' then 'Printer_Station_Customer_Returns_QC_05'
	when 'Printer_Station_Returns_QC_06' then 'Printer_Station_Customer_Returns_QC_06'
	when 'Printer_Station_Returns_QC_07' then 'Printer_Station_Customer_Returns_QC_07'
	when 'Printer_Station_Returns_QC_08' then 'Printer_Station_Customer_Returns_QC_08'

	when 'returns_qc_large_01' then 'crs_large_01'
	when 'returns_qc_large_02' then 'crs_large_02'
	when 'returns_qc_large_03' then 'crs_large_03'
	when 'returns_qc_large_04' then 'crs_large_04'
	when 'returns_qc_large_05' then 'crs_large_05'
	when 'returns_qc_large_06' then 'crs_large_06'
	when 'returns_qc_large_07' then 'crs_large_07'
	when 'returns_qc_large_08' then 'crs_large_08'
	when 'returns_qc_small_01' then 'crs_small_01'
	when 'returns_qc_small_02' then 'crs_small_02'
	when 'returns_qc_small_03' then 'crs_small_03'
	when 'returns_qc_small_04' then 'crs_small_04'
	when 'returns_qc_small_05' then 'crs_small_05'
	when 'returns_qc_small_06' then 'crs_small_06'
	when 'returns_qc_small_07' then 'crs_small_07'
	when 'returns_qc_small_08' then 'crs_small_08'

	when 'returns-dc3' then 'srs_doc_1'
	when 'returns_dc3_2' then 'crs_doc_1'
	end
	where value in 
		('Printer_Station_Returns_In_01','Printer_Station_Returns_QC_01',
		'Printer_Station_Returns_In_02','Printer_Station_Returns_QC_02',
		'Printer_Station_Returns_QC_03','Printer_Station_Returns_QC_04',
		'Printer_Station_Returns_QC_05','Printer_Station_Returns_QC_06',
		'Printer_Station_Returns_QC_07','Printer_Station_Returns_QC_08',
		'returns-dc3', 'returns_dc3_2');


update system_config.config_group_setting set sequence = 9 where value = 'Printer_Station_Customer_Returns_QC_08';
update system_config.config_group_setting set sequence = 8 where value = 'Printer_Station_Customer_Returns_QC_07';
update system_config.config_group_setting set sequence = 7 where value = 'Printer_Station_Customer_Returns_QC_06';
update system_config.config_group_setting set sequence = 6 where value = 'Printer_Station_Customer_Returns_QC_05';
update system_config.config_group_setting set sequence = 5 where value = 'Printer_Station_Customer_Returns_QC_04';
update system_config.config_group_setting set sequence = 4 where value = 'Printer_Station_Customer_Returns_QC_03';
update system_config.config_group_setting set sequence = 3 where value = 'Printer_Station_Customer_Returns_QC_02';
update system_config.config_group_setting set sequence = 2 where value = 'Printer_Station_Customer_Returns_QC_01';


insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active) values
	((select id from system_config.config_group where name = 'PrinterStationListReturnsIn' and channel_id = 11), 'printer_station', 'Printer_Station_Customer_Returns_In_01', 2, true),
	((select id from system_config.config_group where name = 'PrinterStationListReturnsIn' and channel_id = 9), 'printer_station', 'Printer_Station_Customer_Returns_In_02', 3, true),
	((select id from system_config.config_group where name = 'PrinterStationListReturnsIn' and channel_id = 10), 'printer_station', 'Printer_Station_Customer_Returns_In_02', 3, true),
	((select id from system_config.config_group where name = 'PrinterStationListReturnsIn' and channel_id = 11), 'printer_station', 'Printer_Station_Customer_Returns_In_02', 3, true),
	((select id from system_config.config_group where name = 'PrinterStationListReturnsIn' and channel_id = 9), 'printer_station', 'Printer_Station_Customer_Returns_In_03', 4, true),
	((select id from system_config.config_group where name = 'PrinterStationListReturnsIn' and channel_id = 10), 'printer_station', 'Printer_Station_Customer_Returns_In_03', 4, true),
	((select id from system_config.config_group where name = 'PrinterStationListReturnsIn' and channel_id = 11), 'printer_station', 'Printer_Station_Customer_Returns_In_03', 4, true),
	((select id from system_config.config_group where name = 'PrinterStationListReturnsIn' and channel_id = 9), 'printer_station', 'Printer_Station_Customer_Returns_In_04', 5, true),
	((select id from system_config.config_group where name = 'PrinterStationListReturnsIn' and channel_id = 10), 'printer_station', 'Printer_Station_Customer_Returns_In_04', 5, true),
	((select id from system_config.config_group where name = 'PrinterStationListReturnsIn' and channel_id = 11), 'printer_station', 'Printer_Station_Customer_Returns_In_04', 5, true),

	((select id from system_config.config_group where name = 'PrinterStationListReturnsQC' and channel_id = 9), 'printer_station', 'Printer_Station_Sample_Returns_QC_01', 1, true),
	((select id from system_config.config_group where name = 'PrinterStationListReturnsQC' and channel_id = 10), 'printer_station', 'Printer_Station_Sample_Returns_QC_01', 1, true),
	((select id from system_config.config_group where name = 'PrinterStationListReturnsQC' and channel_id = 11), 'printer_station', 'Printer_Station_Sample_Returns_QC_01', 1, true),

	((select id from system_config.config_group where name = 'Printer_Station_Customer_Returns_In_02'), 'printer', 'crs_doc_2', 3, true),
	((select id from system_config.config_group where name = 'Printer_Station_Customer_Returns_In_03'), 'printer', 'crs_doc_3', 4, true),
	((select id from system_config.config_group where name = 'Printer_Station_Customer_Returns_In_04'), 'printer', 'crs_doc_4', 5, true),
	((select id from system_config.config_group where name = 'Printer_Station_Sample_Returns_QC_01'), 'printer_large', 'sample_return_large', 1, true),
	((select id from system_config.config_group where name = 'Printer_Station_Sample_Returns_QC_01'), 'printer_small', 'sample_return_small', 2, true);

commit;
