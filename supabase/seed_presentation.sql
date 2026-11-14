-- Presentation-only sample records for the most recently created Mahal organisation.
-- Run after the schema migration in Supabase SQL Editor. Safe to re-run.
-- All names and amounts below are fictional. Remove these rows before production use.
do $$
declare
  org uuid;
  w1 uuid; w2 uuid; w3 uuid;
begin
  select id into org from public.organisations order by created_at desc limit 1;
  if org is null then raise exception 'Create an organisation first, then run this seed script.'; end if;

  insert into public.wards(organisation_id,ward_number,name,representative_name,phone)
  values (org,'D01','North Ward','Abdul Rahman','9000000101')
  on conflict(organisation_id,ward_number) do update set name=excluded.name
  returning id into w1;
  insert into public.wards(organisation_id,ward_number,name,representative_name,phone)
  values (org,'D02','Central Ward','Fathima Basheer','9000000102')
  on conflict(organisation_id,ward_number) do update set name=excluded.name
  returning id into w2;
  insert into public.wards(organisation_id,ward_number,name,representative_name,phone)
  values (org,'D03','South Ward','Yusuf Kareem','9000000103')
  on conflict(organisation_id,ward_number) do update set name=excluded.name
  returning id into w3;

  insert into public.families(organisation_id,ward_id,family_code,family_name,house_name,house_number,address,post_office,pin_code,phone,whatsapp,registration_date,membership_status)
  values
    (org,w1,'DEMO-F001','Rahman Family','Green Villa','12/A','Market Road','Mahal PO','673001','9000001001','9000001001',current_date-interval '4 years','active'),
    (org,w1,'DEMO-F002','Basheer Family','Noor Manzil','14/B','River Lane','Mahal PO','673001','9000001002','9000001002',current_date-interval '3 years','active'),
    (org,w2,'DEMO-F003','Kareem Family','Darussalam','22','Station Road','Mahal PO','673001','9000001003','9000001003',current_date-interval '2 years','active'),
    (org,w2,'DEMO-F004','Amina Family','Safa House','25/C','Garden Street','Mahal PO','673001','9000001004','9000001004',current_date-interval '1 year','active'),
    (org,w3,'DEMO-F005','Hassan Family','Hill View','31','Hill Road','Mahal PO','673002','9000001005','9000001005',current_date-interval '9 months','active'),
    (org,w3,'DEMO-F006','Salim Family','Al Huda','33/A','Palm Avenue','Mahal PO','673002','9000001006','9000001006',current_date-interval '6 months','active')
  on conflict(organisation_id,family_code) do update set family_name=excluded.family_name,ward_id=excluded.ward_id;

  insert into public.members(organisation_id,family_id,member_code,full_name,malayalam_name,gender,date_of_birth,relationship_to_head,phone,occupation,member_status)
  select org,f.id,m.member_code,m.full_name,m.malayalam_name,m.gender,m.dob,m.relation,m.phone,m.job,'active'
  from (values
    ('DEMO-F001','DEMO-M001','Abdul Rahman','അബ്ദുൽ റഹ്മാൻ','male',date '1978-03-12','Family head','9000001101','Teacher'),
    ('DEMO-F001','DEMO-M002','Aisha Rahman','ആയിഷ റഹ്മാൻ','female',date '1982-07-24','Spouse','9000001102','Nurse'),
    ('DEMO-F001','DEMO-M003','Yusuf Rahman','യൂസഫ് റഹ്മാൻ','male',date '2005-01-06','Son','9000001103','Student'),
    ('DEMO-F002','DEMO-M004','Basheer Ahmed','ബഷീർ അഹമ്മദ്','male',date '1969-11-19','Family head','9000001104','Shop owner'),
    ('DEMO-F002','DEMO-M005','Fathima Basheer','ഫാത്തിമ ബഷീർ','female',date '1974-05-08','Spouse','9000001105','Homemaker'),
    ('DEMO-F003','DEMO-M006','Kareem Usman','കരീം ഉസ്മാൻ','male',date '1986-09-14','Family head','9000001106','Accountant'),
    ('DEMO-F003','DEMO-M007','Mariam Kareem','മറിയം കരീം','female',date '2012-02-03','Daughter','9000001107','Student'),
    ('DEMO-F004','DEMO-M008','Amina Niyas','ആമിന നിയാസ്','female',date '1990-06-22','Family head','9000001108','Teacher'),
    ('DEMO-F004','DEMO-M009','Niyas Amina','നിയാസ് ആമിന','male',date '1988-12-05','Spouse','9000001109','Electrician'),
    ('DEMO-F005','DEMO-M010','Hassan Ali','ഹസ്സൻ അലി','male',date '1958-04-17','Family head','9000001110','Retired'),
    ('DEMO-F006','DEMO-M011','Salim P K','സലീം പി കെ','male',date '1981-08-30','Family head','9000001111','Driver'),
    ('DEMO-F006','DEMO-M012','Sara Salim','സാറ സലീം','female',date '2015-10-11','Daughter','9000001112','Student')
  ) as m(family_code,member_code,full_name,malayalam_name,gender,dob,relation,phone,job)
  join public.families f on f.organisation_id=org and f.family_code=m.family_code
  on conflict(organisation_id,member_code) do update set full_name=excluded.full_name,family_id=excluded.family_id;

  insert into public.accounts(organisation_id,name,account_type,opening_balance)
  values (org,'Demo Cash','cash',12500),(org,'Demo Bank','bank',87500)
  on conflict(organisation_id,name) do nothing;
  insert into public.funds(organisation_id,name,restricted,description)
  values (org,'General Fund',false,'General community operations'),(org,'Zakat Fund',true,'Restricted zakat distributions'),(org,'Madrasa Fund',true,'Madrasa education and supplies')
  on conflict(organisation_id,name) do nothing;
  insert into public.account_categories(organisation_id,name,direction)
  values (org,'Membership fees','income'),(org,'General donations','income'),(org,'Utilities','expense'),(org,'Community welfare','expense')
  on conflict(organisation_id,name,direction) do nothing;

  insert into public.transactions(organisation_id,account_id,category_id,fund_id,direction,amount,transaction_date,description,payment_method,approval_status)
  select org,a.id,c.id,fu.id,x.direction,x.amount,(date_trunc('month',current_date)::date+x.day_offset),x.description,x.method,'approved'
  from (values
    ('income',12500::numeric,1,'Monthly membership collection','cash','Membership fees','General Fund'),
    ('income',8200::numeric,4,'Friday community collection','cash','General donations','General Fund'),
    ('income',25000::numeric,7,'Community contribution','bank','General donations','General Fund'),
    ('expense',6800::numeric,9,'Electricity and water bill','bank','Utilities','General Fund'),
    ('expense',4200::numeric,12,'Madrasa learning materials','cash','Community welfare','Madrasa Fund')
  ) as x(direction,amount,day_offset,description,method,category,fund)
  join public.accounts a on a.organisation_id=org and a.name=case when x.method='cash' then 'Demo Cash' else 'Demo Bank' end
  join public.account_categories c on c.organisation_id=org and c.name=x.category and c.direction=x.direction
  join public.funds fu on fu.organisation_id=org and fu.name=x.fund
  where not exists(select 1 from public.transactions t where t.organisation_id=org and t.description=x.description and t.transaction_date=(date_trunc('month',current_date)::date+x.day_offset));

  insert into public.donors(organisation_id,name,phone,anonymous)
  select org,x.name,x.phone,x.anonymous from (values ('Community member','9000002001',false),('Local benefactor','9000002002',false),('Anonymous donor',null,true)) x(name,phone,anonymous)
  where not exists(select 1 from public.donors d where d.organisation_id=org and d.name is not distinct from x.name);
  insert into public.donations(organisation_id,donor_id,fund_id,amount,donation_date,purpose,payment_method,receipt_number)
  select org,d.id,fu.id,x.amount,current_date-(x.days_ago||' days')::interval,x.purpose,'cash',x.receipt
  from (values ('Community member',5000::numeric,2,'Madrasa support','DEMO-R001'),('Local benefactor',10000::numeric,5,'General community support','DEMO-R002'),('Anonymous donor',2500::numeric,1,'Friday collection','DEMO-R003')) x(donor_name,amount,days_ago,purpose,receipt)
  join public.donors d on d.organisation_id=org and d.name=x.donor_name
  left join public.funds fu on fu.organisation_id=org and fu.name=case when x.purpose='Madrasa support' then 'Madrasa Fund' else 'General Fund' end
  where not exists(select 1 from public.donations d2 where d2.organisation_id=org and d2.receipt_number=x.receipt);

  insert into public.events(organisation_id,title,description,starts_at,location,speaker)
  select org,x.title,x.description,x.starts_at,x.location,x.speaker from (values
    ('Friday Community Gathering','Weekly reminder and community gathering',date_trunc('week',now())+interval '4 days 12 hours','Mahal Main Hall','Imam Kareem'),
    ('Youth Study Circle','An evening of learning and discussion',now()+interval '5 days','Madrasa Hall','Ustadh Yusuf'),
    ('Family Wellness Day','Community health checks and family activities',now()+interval '12 days','Community Centre','Dr. Amina')
  ) x(title,description,starts_at,location,speaker)
  where not exists(select 1 from public.events e where e.organisation_id=org and e.title=x.title);

  insert into public.announcements(organisation_id,title,body,language,starts_at,expires_at,published)
  select org,x.title,x.body,x.language,now(),now()+interval '30 days',true from (values
    ('Jumu’ah Prayer','Jumu’ah prayer will be held at 1:15 PM. Please arrive a few minutes early.','en'),
    ('മഹല്ല് അറിയിപ്പ്','വെള്ളിയാഴ്ച ജുമുഅ നമസ്കാരം ഉച്ചയ്ക്ക് 1:15 ന് നടക്കുന്നതാണ്.','ml'),
    ('Community Gathering','All families are warmly invited to the upcoming community programme.','en')
  ) x(title,body,language)
  where not exists(select 1 from public.announcements a where a.organisation_id=org and a.title=x.title);
end $$;
