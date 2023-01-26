SELECT column_name, column_type,

CONCAT(
'public ', 
CASE 
WHEN column_type ='int' THEN 'int'
WHEN column_type ='int unsigned' THEN 'long'
WHEN column_type ='bigint' THEN 'long'
WHEN column_type ='datetime' THEN 'DateTime'
WHEN column_type ='date' THEN 'DateTime'
WHEN column_type LIKE 'varchar(%' THEN 'string'
WHEN column_type = 'char(1)' THEN 'char'
WHEN column_type LIKE 'char(%' THEN 'string'
WHEN column_type LIKE 'decimal(%' THEN 'decimal'

ELSE 'NotImplemented' END , 
' ',
column_name, 
' {get;set;}'

) AS CODE
 FROM information_schema.COLUMNS
WHERE table_name='mytable';
