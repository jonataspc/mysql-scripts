# Author: Jonatas Cruz
# https://github.com/jonataspc/mysql-scripts

DELIMITER $$

DROP PROCEDURE IF EXISTS `TablesAutoIncrementUsage`$$

CREATE
    
    PROCEDURE `TablesAutoIncrementUsage`()
    DETERMINISTIC
      COMMENT 'Get tables auto increment usage ' 
	BEGIN

DECLARE _table_schema VARCHAR(64); 
DECLARE _table_name VARCHAR(64);
DECLARE _column_name VARCHAR(64);
DECLARE _data_type VARCHAR(64);
DECLARE _column_type LONGTEXT;
DECLARE done INT DEFAULT 0;
DECLARE _maxValueSigned BIGINT UNSIGNED; 

DECLARE op_cursor CURSOR FOR
SELECT table_schema, table_name, column_name, column_type, UPPER(data_type) AS data_type FROM information_schema.COLUMNS 
JOIN information_schema.TABLES USING (table_schema, table_name)
WHERE table_schema NOT IN ('mysql','information_schema','performance_schema') AND extra LIKE '%auto_increment%' AND information_schema.TABLES.ENGINE <> 'FEDERATED'
ORDER BY table_schema, table_name, column_name ;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
OPEN op_cursor;

-- temp table to store the statistics
DROP TEMPORARY TABLE IF EXISTS tmp_auto_increment_usage;
CREATE TEMPORARY TABLE tmp_auto_increment_usage (table_schema VARCHAR(64) NOT NULL, table_name VARCHAR(64) NOT NULL, column_name VARCHAR(64) NOT NULL, column_type LONGTEXT NOT NULL, current_id BIGINT UNSIGNED NOT NULL, usage_percentage DECIMAL(8,5));

REPEAT
FETCH op_cursor INTO _table_schema, _table_name, _column_name, _column_type, _data_type;

IF NOT done THEN
	
	SET @query = CONCAT('SELECT MAX(`', _column_name, '`) INTO @current_id FROM `', _table_schema, '`.`', _table_name, '`; ');
	PREPARE statement1 FROM @query;
	EXECUTE statement1;	
	
	IF @current_id IS NULL THEN
		SET @current_id = 0;
	END IF;
		
	# check datatype limits
	CASE _data_type
	WHEN 'TINYINT' THEN 
		SET _maxValueSigned = 127;
	WHEN 'SMALLINT' THEN 
		SET _maxValueSigned = 32767;
	WHEN 'MEDIUMINT' THEN 
		SET _maxValueSigned = 8388607;
	WHEN 'INT' THEN 
		SET _maxValueSigned = 2147483647;
	WHEN 'BIGINT' THEN 
		SET _maxValueSigned = 9223372036854775807;
	ELSE
		SET _maxValueSigned  = 0;
	END CASE;	
	
	IF LOWER(_column_type) LIKE '%unsigned%' THEN
		SET _maxValueSigned  = (_maxValueSigned * 2) + 1;
	END IF;

	SET @usage_percentage = 100 * @current_id / _maxValueSigned; 
	
	INSERT INTO tmp_auto_increment_usage VALUES (_table_schema, _table_name, _column_name, _column_type, @current_id, @usage_percentage);
	
END IF;
UNTIL done END REPEAT;
CLOSE op_cursor;
 
SELECT * FROM tmp_auto_increment_usage ORDER BY table_schema, table_name, column_name ;
DROP TEMPORARY TABLE tmp_auto_increment_usage;


	END$$

DELIMITER ;
