DROP FUNCTION murder() cascade;
DROP trigger on_slayer_added on human;
CREATE OR REPLACE FUNCTION murder()
    RETURNS trigger
AS
$$
DECLARE
    var_r        record;
    att          record;
    killedHealth int;
BEGIN
    SELECT health INTO killedHealth FROM human WHERE humanid = new.humanid;
    if (killedHealth > 0) THEN
        UPDATE human SET health = 0 WHERE humanid = new.humanid;
        for var_r in (SELECT groupid FROM attitude where ((humanid = new.humanid) AND (loyality_level >= 66)))
            loop
                select loyality_level
                INTO att
                from attitude
                where (groupid = var_r.groupid)
                  AND (humanid = new.slayerID);
                if (att.loyality_level < 10) THEN
                    UPDATE attitude
                    SET loyality_level = 0
                    WHERE ((humanid = new.slayerid) AND (groupid = var_r.groupid));
                ELSE
                    UPDATE attitude
                    SET loyality_level = (att.loyality_level - 10)
                    WHERE ((humanid = new.slayerid) AND (groupid = var_r.groupid));
                end if;
            end loop;
        for var_r in (SELECT groupid FROM attitude where ((humanid = new.humanid) AND (loyality_level < 33)))
            loop
                select loyality_level
                INTO att
                from attitude
                where (groupid = var_r.groupid)
                  AND (humanid = new.slayerid);
                if (att.loyality_level > 90) THEN
                    UPDATE attitude
                    SET loyality_level = 100
                    WHERE ((humanid = new.slayerid) AND (groupid = var_r.groupid));
                ELSE
                    UPDATE attitude
                    SET loyality_level = (att.loyality_level + 7)
                    WHERE ((humanid = new.slayerid) AND (groupid = var_r.groupid));
                end if;
            end loop;
        return new;
    end if;

    return null;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER on_slayer_added
    AFTER UPDATE
    ON human
    FOR EACH ROW
    WHEN (OLD.SlayerID IS DISTINCT FROM NEW.SlayerID)
EXECUTE PROCEDURE murder();

DROP FUNCTION deal() cascade;
DROP trigger on_trader_has_customer on trader;
CREATE OR REPLACE FUNCTION deal()
    RETURNS trigger
AS
$$
DECLARE
    var_r        record;
    att          record;
    weapon       record;
    customer     record;
    traderPerson record;
    setPrice     integer;
    weaponTypeID integer;
BEGIN
    SELECT mother_groupid INTO var_r FROM trader WHERE humanid = new.humanid;
    SELECT loyality_level
    INTO att
    FROM attitude
    WHERE ((humanid = new.customerID) AND (groupid = var_r.mother_groupid));
    SELECT * INTO customer FROM human WHERE humanid = new.customerid;
    SELECT * INTO traderPerson FROM human WHERE humanid = new.humanid;

    if (customer.weaponid < 8) THEN
        weaponTypeID = (customer.weaponid + 1);
        SELECT * INTO weapon FROM weapon_type WHERE weaponid = weaponTypeID;
        setPrice = weapon.price;
        if (att.loyality_level < 33) THEN
            setPrice = weapon.price * 1.15;
        end if;
        if (att.loyality_level >= 66) THEN
            setPrice = weapon.price * 0.9;
        end if;
        IF (customer.money >= setPrice) THEN
            UPDATE human SET money = customer.money - setPrice WHERE humanid = new.customerID;
            UPDATE human SET weaponid = weaponTypeID WHERE humanid = new.customerID;
            UPDATE human SET money = traderPerson.money + setPrice WHERE humanid = new.humanid;
        end if;
    end if;
    return new;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER on_trader_has_customer
    BEFORE UPDATE OF customerid
    ON trader
    FOR EACH ROW
    WHEN (OLD.customerID IS DISTINCT FROM NEW.customerID AND NEW.customerID IS NOT NULL)
EXECUTE PROCEDURE deal();

-- Правка данных в случае несоответствия принадлежащей группы и уровня отношения
DROP FUNCTION correctingMemberLoyality() CASCADE;
DROP trigger correctingMemberLoyality on attitude;
CREATE OR REPLACE FUNCTION correctingMemberLoyality()
    RETURNS TRIGGER
AS
$correctingMemberLoyality$
DECLARE
    warriorHuman record;
    attitudeRec  record;
BEGIN
    IF NEW.loyality_level < 0 THEN
        RAISE EXCEPTION 'Wrong loyality level';
    end if;

    SELECT * INTO warriorHuman FROM warrior WHERE (humanid = NEW.humanID);
    if ((NEW.loyality_level < 66) AND (NEW.groupid = warriorHuman.mother_groupid)) THEN
        NEW.loyality_level := 66;
    end if;

    return NEW;
END;
$correctingMemberLoyality$ LANGUAGE plpgsql;
CREATE TRIGGER correctingMemberLoyality
    BEFORE INSERT OR UPDATE
    ON attitude
    FOR EACH ROW
EXECUTE PROCEDURE correctingMemberLoyality();

-- Триггер на добавление SLAYER. Необходмо проверять, что такой Slayer существует
DROP FUNCTION addSlayer();
DROP trigger addSlayer on human;
CREATE OR REPLACE FUNCTION addSlayer()
    RETURNS TRIGGER
AS
$addSlayer$
DECLARE
    slayer record;
BEGIN

    if (OLD.health <= 0) THEN
        RAISE EXCEPTION 'Human is already dead';
    end if;


    if (NEW.is_slayed_by = 'HUMAN') THEN
        if (SELECT exists(SELECT 1 FROM human where humanid = NEW.slayerid)) THEN
            SELECT * INTO slayer FROM human where humanid = NEW.slayerid;
            if (slayer.health > 0) THEN
                return NEW;
            end if;
            RAISE EXCEPTION 'Human slayer is dead';
        end if;
        RAISE EXCEPTION 'No such human';
    end if;

    if (NEW.is_slayed_by = 'MUTANT') THEN
        if (SELECT exists(SELECT 1 FROM mutant where mutantid = NEW.slayerid)) THEN
            SELECT * INTO slayer FROM mutant where mutantid = NEW.slayerid;
            if (slayer.health > 0) THEN
                return NEW;
            end if;
            RAISE EXCEPTION 'Mutant slayer is dead';
        end if;
        RAISE EXCEPTION 'No such mutant';
    end if;

    if (NEW.is_slayed_by = 'MUTANT') THEN
        if (SELECT exists(SELECT 1 FROM anomaly where anomalyid = NEW.slayerid)) THEN
            return NEW;
        end if;
        RAISE EXCEPTION 'No such anomaly';
    end if;

    RAISE EXCEPTION 'No such slayer type';

END;
$addSlayer$ LANGUAGE plpgsql;
CREATE TRIGGER addSlayer
    BEFORE INSERT OR UPDATE OF slayerid
    ON human
    FOR EACH ROW
EXECUTE PROCEDURE addSlayer();

-- Триггер на добавление SLAYER. Необходмо проверять, что такой Slayer существует
DROP FUNCTION addArtifact();
DROP trigger addArtifact on human;

CREATE OR REPLACE FUNCTION addArtifact()
    RETURNS TRIGGER
AS
$addArtifact$
DECLARE
    newOwner record;
    oldOwner record;
BEGIN
    IF (OLD.ownerid IS NOT NULL) THEN
        SELECT * INTO oldOwner FROM human WHERE humanid = OLD.ownerid;
        IF (oldOwner.health > 0) THEN
            IF (oldOwner.health <= OLD.health_change) THEN
                UPDATE human SET slayerid = NEW.ownerid, is_slayed_by = 'HUMAN' WHERE humanid = oldOwner.humanid;
            ELSE
                UPDATE human
                SET health = oldOwner.health - OLD.health_change,
                    speed  = oldOwner.speed - OLD.speed_change
                WHERE humanid = oldOwner.humanid;
            end if;
        end if;
    end if;

    SELECT * INTO newOwner FROM human WHERE humanid = new.ownerid;
    UPDATE human
    SET health = newOwner.health + OLD.health_change, speed = OLD.speed_change
    where humanid = newOwner.humanid;

    return NEW;
END;
$addArtifact$ LANGUAGE plpgsql;
CREATE TRIGGER addArtifact
    BEFORE INSERT OR UPDATE OF ownerid
    ON artifact
    FOR EACH ROW
EXECUTE PROCEDURE addArtifact();