CREATE OR REPLACE FUNCTION reset_human_stats()
  RETURNS TRIGGER
  LANGUAGE PLPGSQL
  AS
$$
BEGIN
	UPDATE HUMAN SET health = 0, speed = 0 WHERE humanID = new.humanID;
	RETURN NEW;
END;
$$;

CREATE TRIGGER on_slayer_added
    AFTER UPDATE ON human
    FOR EACH ROW
    WHEN (OLD.SlayerID IS DISTINCT FROM NEW.SlayerID)
    EXECUTE PROCEDURE reset_human_stats();

-- CREATE TRIGGER on_slay_by_human
--     AFTER UPDATE ON human
--     FOR EACH ROW
--     WHEN (OLD.Is_slayed_by IS DISTINCT FROM NEW.Is_slayed_by AND NEW.Is_slayed_by = 'HUMAN')
--     EXECUTE PROCEDURE murder(new.humanID, new.slayerID);

-- DROP TRIGGER on_trader_has_customer on trader;
CREATE TRIGGER on_trader_has_customer
    AFTER UPDATE
    ON trader
    FOR EACH ROW
    WHEN (OLD.customerID IS DISTINCT FROM NEW.customerID AND NEW.customerID IS NOT NULL)
EXECUTE PROCEDURE deal(NEW.humanID, NEW.customerID);


-- CREATE TRIGGER on_close_each_other
--     AFTER UPDATE ON human
--     FOR EACH ROW
--     WHEN (OLD.geolocation IS DISTINCT FROM NEW.geolocation)
--     EXECUTE PROCEDURE battle(new.humanID);
