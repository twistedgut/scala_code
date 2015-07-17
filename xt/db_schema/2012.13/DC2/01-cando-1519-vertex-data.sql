BEGIN WORK;

INSERT
  INTO vertex_area (
      country,
      county
  )
  VALUES ( 'United States', 'NY' ),
         ( 'United States', 'NJ' )
;

INSERT
  INTO vertex_area (
      country
  )
  VALUES ( 'Canada'  )
;

COMMIT WORK;
