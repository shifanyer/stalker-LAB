DROP FUNCTION battle(integer);
CREATE OR REPLACE FUNCTION battle(initiatorID integer)
    RETURNS INTEGER
AS
$$
DECLARE
    initiator       record;
    victim          record;
    weapon1         record;
    weapon2         record;
    groupWarrior    record;
    var_r           record;
    initiatorHealth integer;
    victimHealth    integer;
    att             record;

BEGIN
    SELECT * INTO initiator FROM human WHERE humanid = initiatorID;
    SELECT * INTO weapon1 FROM weapon_type WHERE weaponid = initiator.weaponid;

    for victim in (SELECT *
                   FROM human
                   where ((abs(initiator.geolocation[0] - victim.geolocation[0]) < 0.5) AND
                          (abs(initiator.geolocation[1] - victim.geolocation[1]) < 0.5)))
        LOOP
            SELECT * INTO weapon2 FROM weapon_type WHERE weaponid = victim.weaponid;
            SELECT * INTO groupWarrior FROM warrior where humanid = victim.humanid;
            if (SELECT exists(SELECT * INTO var_r FROM warrior where humanid = victim.humanid)) THEN
                SELECT *
                INTO att
                FROM attitude
                WHERE ((humanid = initiator.humanid) AND (groupid = groupWarrior.mother_groupid));
                if (att < 33) THEN
                    initiatorHealth = initiator.health;
                    victimHealth = victim.health;
                    WHILE ((initiatorHealth > 0) AND (victimHealth > 0))
                        LOOP
                            victimHealth = victimHealth - weapon1.damage;
                            IF (victimHealth > 0) THEN
                                initiatorHealth = initiatorHealth - weapon2.damage;
                            end if;
                        end loop;
                    IF (initiatorHealth <= 0) THEN
                        UPDATE human SET health = victimHealth WHERE humanid = victim.humanid;
                        UPDATE human
                        SET initiator.health       = 0,
                            initiator.is_slayed_by = 'HUMAN',
                            initiator.slayerid     = victim.humanid = 0
                        WHERE humanid = initiator.humanid;
                        return victim.humanid;
                    ELSE
                        UPDATE human SET health = initiatorHealth WHERE humanid = initiatorID;
                        UPDATE human
                        SET victim.health       = 0,
                            victim.is_slayed_by = 'HUMAN',
                            victim.slayerid     = initiator.humanid = 0
                        WHERE humanid = victim.humanid;
                        return initiatorID;
                    end if;
                end if;
            end if;
        end loop;
    return initiatorID;

END;
$$ LANGUAGE plpgsql;

DROP FUNCTION buyWeapon(integer, integer, integer);
CREATE OR REPLACE FUNCTION buyWeapon(reqCustomerID integer, traderID integer, reqWeaponID integer)
    RETURNS INTEGER
AS
$$
DECLARE
    traderTrader    record;
    traderHuman     record;
    customer        record;
    att             record;
    weaponRec       record;
    setPrice        float;
    attitudeToHuman float;
    bestVVP         record;
BEGIN
    IF (SELECT 1 FROM trader WHERE humanid = traderID) THEN
        SELECT * INTO traderTrader FROM trader WHERE humanid = traderID;
        SELECT * INTO traderHuman FROM human WHERE humanid = traderID;
        if (traderHuman.health > 0) THEN
            IF (SELECT 1 FROM human WHERE humanid = reqCustomerID) THEN
                SELECT * INTO customer FROM human WHERE humanid = reqCustomerID;
                IF (customer.health > 0) THEN
                    IF (SELECT 1 FROM weapon_type WHERE reqWeaponID = weaponID) THEN
                        SELECT * INTO weaponRec FROM weapon_type WHERE reqWeaponID = weaponID;
--                         UPDATE trader SET customerid = reqCustomerID WHERE humanid = traderID;
                        SELECT *
                        INTO att
                        FROM attitude
                        WHERE ((humanid = reqCustomerID) AND (groupid = traderTrader.mother_groupid));
                        setPrice := weaponRec.price;
                        attitudeToHuman := att.loyality_level * 1.0;
                        SELECT groupID,
                               SUM(COALESCE(money, 0))                              as summ_money,
                               MAX(COALESCE(h.humanid, 0))                          as maxID,
                               count(t.humanid)                                     as traders_in_group,
                               ((SUM(COALESCE(money, 0)) * 1.0) / (count(*) * 1.0)) as VVP
                        INTO bestVVP
                        FROM grouping
                                 LEFT JOIN trader t on grouping.groupid = t.mother_groupid
                                 LEFT JOIN human h on t.humanid = h.humanid
                        GROUP BY groupid
                        ORDER BY VVP DESC
                        LIMIT 1;
                        IF (traderTrader.mother_groupid = bestVVP.groupid) THEN
                            attitudeToHuman = attitudeToHuman * 1.1;
                        end if;
                        if (attitudeToHuman < 33.0) THEN
                            setPrice := weaponRec.price * 1.05;
                        end if;
                        if (attitudeToHuman >= 66.0) THEN
                            setPrice := weaponRec.price * 0.9;
                        end if;
                        IF (customer.money >= setPrice) THEN
                            UPDATE human SET money = customer.money - setPrice WHERE humanid = reqCustomerID;
                            UPDATE human SET weaponid = reqWeaponID WHERE humanid = reqCustomerID;
                            UPDATE human SET money = traderHuman.money + setPrice WHERE humanid = traderID;
                            Return setPrice;
                        end if;
                        RAISE EXCEPTION 'not enough money';
                    end if;
                    RAISE EXCEPTION 'no weapon with such ID';
                end if;
                RAISE EXCEPTION 'Customer is dead';
            end if;
            RAISE EXCEPTION 'no Customer with such ID';
        end if;
        RAISE EXCEPTION 'Trader is dead';
    end if;
    RAISE EXCEPTION 'no Traders with such ID';

END;
$$ LANGUAGE plpgsql;

drop FUNCTION buildRoute(integer, point, point);
CREATE OR REPLACE FUNCTION buildRoute(travelerID integer, startPoint POINT, finalPoint POINT)
    RETURNS INTEGER
AS
$$
DECLARE
    traveler        record;
    newRoute        record;
    finalRoutePoint record;
    lastID          integer;
    firstRouteID    integer;
    a               Float;
    b               Float;
    xValue          FLOAT;
    yValue          FLOAT;
BEGIN

    SELECT * INTO traveler FROM human where humanid = travelerID;
    a := (finalPoint[1] - startPoint[1]) / (finalPoint[0] - startPoint[0]);
    b := startPoint[1] -
         (finalPoint[1] - startPoint[1]) / (finalPoint[0] - startPoint[0]) *
         startPoint[0];

    --     EXECUTE 'SELECT COUNT(routeid) FROM ROUTE' INTO routesAmount;
--     SET routesAmount = (SELECT COUNT(routeid) FROM ROUTE);
    INSERT INTO route (start_geolocation, final_geolocation, start_pointID)
    VALUES (startPoint, finalPoint, -1);

    Select * into newRoute FROM route WHERE start_pointid = -1;

    INSERT INTO route_points (routeID, geolocation, next_pointID) VALUES (newRoute.routeid, finalPoint, NULL);
    Select * into finalRoutePoint FROM route_points WHERE routeID = newRoute.routeid;
    lastID := finalRoutePoint.pointid;
    firstRouteID := finalRoutePoint.pointid;
    xValue := finalPoint[0];
    WHILE (xValue <> startPoint[0])
        LOOP
            if (xValue < startPoint[0]) THEN
                xValue := xValue + 1.0;
            ELSE
                xValue := xValue - 1.0;
            end if;
            yValue := a * xValue + b;
            if (abs(xValue - startPoint[0]) < 1.0) THEN
                xValue := startPoint[0];
                INSERT INTO route_points (routeID, geolocation, next_pointID)
                VALUES (newRoute.routeid, startPoint, lastID);
            ELSE
                INSERT INTO route_points (routeID, geolocation, next_pointID)
                VALUES (newRoute.routeid, POINT(xValue, yValue), lastID);
            end if;
            lastID := lastID + 1;
        end loop;
    INSERT INTO human_route (humanid, routeid) VALUES (travelerID, newRoute.routeid);
    UPDATE route SET start_pointid = lastID WHERE routeid = newRoute.routeid;
    RETURN newRoute.routeid;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION pathToArtifact(integer, TEXT);
CREATE OR REPLACE FUNCTION pathToArtifact(seekerID integer, artifactName text)
    RETURNS INTEGER
AS
$$
DECLARE
    artifactObj        record;
    humanObj           record;
    artifactsLocations record;
    startingPoint      point;
    resultRouteLength  float;
    lastRouteID        integer;
BEGIN

    SELECT * INTO humanObj FROM human where humanid = seekerID;

    if (humanObj.health > 0) THEN
        --         SELECT *,
--                (|/(1.0 * (humanObj.geolocation[0] - an.geolocation[0]) ^ 2 +
--                    1.0 * (humanObj.geolocation[1] - an.geolocation[1]) ^ 2)) as dist
--         INTO artifactsLocations
--         FROM artifact art
--                  JOIN anomaly an on art.anomalyid = an.anomalyid
--         WHERE (art.name like artifactName)
--           AND (ownerid IS NULL)
--         ORDER BY dist;

        startingPoint := humanObj.geolocation;
        resultRouteLength := 0;
        FOR artifactObj in SELECT *,
                                  (|/(1.0 * (humanObj.geolocation[0] - an.geolocation[0]) ^ 2 +
                                      1.0 * (humanObj.geolocation[1] - an.geolocation[1]) ^ 2)) as dist
                           FROM artifact art
                                    JOIN anomaly an on art.anomalyid = an.anomalyid
                           WHERE (art.name like artifactName)
                             AND (ownerid IS NULL)
                           ORDER BY dist
            LOOP
                lastRouteID := buildroute(seekerID, startingPoint, artifactObj.geolocation);
                resultRouteLength := resultRouteLength +
                                     artifactObj.dist;
                startingPoint = artifactObj.geolocation;
            end loop;

        return resultRouteLength;

    end if;

    RAISE EXCEPTION 'Seeker is dead';
END;
$$ LANGUAGE plpgsql;