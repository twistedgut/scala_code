-- tidying up the old reporting hierarchy to come inline with new navigation hierarchy

BEGIN;

ALTER TABLE classification ADD COLUMN deleted boolean default false;
ALTER TABLE product_type ADD COLUMN deleted boolean default false;
ALTER TABLE sub_type DROP COLUMN product_type_id;
ALTER TABLE sub_type ADD COLUMN deleted boolean default false;

UPDATE classification SET deleted = true WHERE classification NOT IN ('Accessories', 'Clothing', 'Bags', 'Shoes');

UPDATE product_type SET deleted = true WHERE product_type NOT IN ('Totes', 'Shoulder Bags', 'Clutch Bags', 'Weekend', 'Technology', 'Small Leather Goods', 'Belts', 'Hair Accessories', 'Jewelry', 'Hats Gloves & Scarves', 'Sunglasses', 'Lifestyle', 'Umbrellas', 'Watches', 'Coats', 'Dresses', 'Jackets', 'Skirts', 'Pants', 'Jeans', 'Tops', 'Knitwear', 'Swimwear', 'Lingerie', 'Hosiery', 'Flats', 'Mid Heels', 'High Heels', 'Boots');

UPDATE sub_type SET deleted = true WHERE sub_type NOT IN ('Day Totes', 'Day Shoulder Bags', 'Day Clutch Bags', 'Evening Totes', 'Evening Shoulder Bags', 'Evening Clutch Bags', 'Oversized Totes', 'Oversized Shoulder Bags', 'Oversized Clutch Bags', 'Wallets', 'Wide', 'Fashion', 'Earrings', 'Hats', 'Plastic', 'Home', 'Fashion', 'Fashion', 'Cosmetic Cases', 'Jeans', 'Hairbands', 'Necklaces', 'Gloves', 'Aviator', 'Notebooks', 'Necklaces', 'Key Fobs', 'Skinny', 'Brooches', 'Scarves', 'Rimless', 'Books', 'Bracelets', 'Bracelets', 'Wraps', 'Metal', 'CD''s', 'Rings', 'Earmuffs', 'DVD''s', 'Anklets', 'Jewelry boxes', 'Cosmetics', 'Pet', 'Long Coats', 'Work', 'Smart Jackets', 'Knee Length', 'Straight Leg', 'Bootcut', 'Blouses', 'Cardigans', 'One Piece', 'Bras', 'Socks', 'Short Coats', 'Fashion', 'Casual Jackets', 'Mini', 'Wide Leg', 'Flared', 'Shirts', 'Sweaters', 'Bikinis', 'Briefs', 'Tights', 'Gilets', 'Black Tie', 'Vests', 'Maxi', 'Skinny Leg', 'Straight Leg', 'Camis', 'Sleeveless', 'Kaftans', 'Garter Belts', 'Leggings', 'Trench Coats', 'Cocktail & Party', 'Evening Jackets', 'Cropped Pants', 'Skinny Leg', 'T-Shirts', 'Poncho', 'Sarongs', 'Camis', 'Capes', 'Wrap', 'Shorts', 'Cropped Jeans', 'Tunics & Kaftans', 'Cardi Coats', 'Cover-ups', 'Chemises', 'Sundresses', 'Track Pants', 'Shorts', 'Tanks', 'Towels', 'Robes', 'Evening & Dinner', 'Jumpsuits', 'Overalls', 'Strapless Tops', 'Wide Leg', 'Track Tops', 'Ballerinas', 'Pumps', 'Pumps', 'Flat', 'Sandals', 'Sandals', 'Sandals', 'Mid Heel', 'Moccasins', 'High Heel', 'Lace ups', 'Sneakers');


CREATE TABLE link_classification__product_type (
	classification_id integer not null references classification(id),
	product_type_id integer not null references product_type(id)
);

-- make sure www can use the table
GRANT ALL ON link_classification__product_type TO www;


CREATE TABLE link_product_type__sub_type (
	product_type_id integer not null references product_type(id),
	sub_type_id integer not null references sub_type(id)
);

-- make sure www can use the table
GRANT ALL ON link_product_type__sub_type TO www;



COMMIT;
