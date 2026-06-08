\set ON_ERROR_STOP on
-- Xoa sach du lieu mau cua prod (giu lai lich su migration)
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename <> '_prisma_migrations' LOOP
    EXECUTE 'TRUNCATE TABLE public.'||quote_ident(r.tablename)||' CASCADE';
  END LOOP;
END $$;
--
-- PostgreSQL database dump
--

\restrict 6D573YpawBCkgf7Z3kNRqzArPzxlWPhKTp0oeQDdKGHaVE13vhq9T0YShvCl5bT

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: Kitchen; Type: TABLE DATA; Schema: public; Owner: -
--

SET SESSION AUTHORIZATION DEFAULT;

ALTER TABLE public."Kitchen" DISABLE TRIGGER ALL;

COPY public."Kitchen" (id, name, address, "capacityPerHour", "createdAt", "updatedAt") FROM stdin;
kitchen-main	Banan Central Kitchen	15 Le Loi, District 1, HCMC	60	2026-05-10 06:28:37.064	2026-05-10 06:28:37.064
\.


ALTER TABLE public."Kitchen" ENABLE TRIGGER ALL;

--
-- Data for Name: Store; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Store" DISABLE TRIGGER ALL;

COPY public."Store" (id, name, slug, address, lat, lng, phone, "openingHours", "defaultKitchenId", "createdAt", "updatedAt", "preparationLeadMinutes", "isPaused", "pauseReason", "minOrderVnd", "defaultLeadHours", "isPickupPaused", "isDeliveryPaused", "wardCode") FROM stdin;
aa237695-edd5-482e-aca5-54401f046b28	Banan – Lê Thánh Tôn	banan-le-thanh-ton	15B8 Lê Thánh Tôn, Bến Nghé Ward, HCMC	10.778	106.703	+84867540939	{"fri": [["10:00", "22:00"]], "mon": [["10:00", "21:30"]], "sat": [["10:00", "22:00"]], "sun": [["10:00", "22:00"]], "thu": [["10:00", "21:30"]], "tue": [["10:00", "21:30"]], "wed": [["10:00", "21:30"]]}	kitchen-main	2026-05-13 09:16:53.742	2026-05-28 18:31:24.096	120	f	selftest	0	2	f	f	sai-gon
92ea4777-1e11-4bca-869c-3e68e3ca2e90	Banan – Sư Vạn Hạnh	banan-su-van-hanh	425A Sư Vạn Hạnh, Hòa Hưng Ward, HCMC	10.7793	106.6678	+84387835035	{"fri": [["10:00", "22:00"]], "mon": [["10:00", "21:30"]], "sat": [["10:00", "22:00"]], "sun": [["10:00", "22:00"]], "thu": [["10:00", "21:30"]], "tue": [["10:00", "21:30"]], "wed": [["10:00", "21:30"]]}	kitchen-main	2026-05-13 09:16:53.777	2026-05-28 09:06:17.528	120	f	\N	0	0	f	f	hoa-hung
36be32a7-9fac-42de-80af-cc74e30c2d03	Banan – Ngô Quang Huy	banan-ngo-quang-huy	34 Ngô Quang Huy, An Khánh Ward, HCMC	10.78	106.733	+84868897131	{"fri": [["10:00", "22:00"]], "mon": [["10:00", "21:30"]], "sat": [["10:00", "22:00"]], "sun": [["10:00", "22:00"]], "thu": [["10:00", "21:30"]], "tue": [["10:00", "21:30"]], "wed": [["10:00", "21:30"]]}	kitchen-main	2026-05-13 09:16:53.784	2026-05-28 09:06:17.532	120	f	\N	0	0	f	f	an-khanh
9a2138f2-4117-460a-a261-2168889da048	Banan – Trường Sa	banan-truong-sa	360 Trường Sa, Cầu Kiệu Ward, HCMC	10.79	106.684	+84379555934	{"fri": [["10:00", "22:00"]], "mon": [["10:00", "21:30"]], "sat": [["10:00", "22:00"]], "sun": [["10:00", "22:00"]], "thu": [["10:00", "21:30"]], "tue": [["10:00", "21:30"]], "wed": [["10:00", "21:30"]]}	kitchen-main	2026-05-13 09:16:53.79	2026-05-28 09:06:17.535	120	f	\N	0	0	f	f	cau-kieu
\.


ALTER TABLE public."Store" ENABLE TRIGGER ALL;

--
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."User" DISABLE TRIGGER ALL;

COPY public."User" (id, email, phone, "passwordHash", "fullName", "avatarUrl", role, "membershipTier", "pointsBalance", birthday, "storeId", "kitchenId", "createdAt", "updatedAt", "merchantNotes", "merchantTags") FROM stdin;
aedd04e8-4140-437f-b66b-0f133c42b11f	admin@banan.local	\N	$2b$10$XY5.aNmkOvZGdBhaNnz7keRGgd6BOwDu/xT3hDrbEnzmxwRLQf/Wi	Banan Admin	\N	ADMIN	SILVER	0	\N	\N	\N	2026-05-10 06:28:37.083	2026-05-10 06:28:37.083	\N	{}
ac5b9cb9-1920-4ff1-accb-3ed91702aefc	merchant-truongsa@banan.local	\N	$2b$10$nqNE4Dzz9bZvbWYtixCqqe.jJi1x/wcOV3ufg4fSZrcqA/ym3VcRa	Trường Sa Manager	\N	MERCHANT_OWNER	SILVER	0	\N	9a2138f2-4117-460a-a261-2168889da048	\N	2026-05-13 09:16:53.833	2026-05-28 09:06:17.557	\N	{}
ab32baa0-382d-48e5-a542-b6f6a3620a9b	kitchen@banan.local	\N	$2b$10$XY5.aNmkOvZGdBhaNnz7keRGgd6BOwDu/xT3hDrbEnzmxwRLQf/Wi	Kitchen Manager	\N	KITCHEN_MANAGER	SILVER	0	\N	\N	kitchen-main	2026-05-10 06:28:37.095	2026-05-28 09:06:17.56	\N	{}
3293c2bf-4ceb-4e45-8597-61bad26a4bad	viet.20121995@gmail.com	+84785911912	$2b$10$wD8LbQzy1zGvTCMZO/37e.VH1WVc2C0Jm6JnEUJE8LO/v0sO.272K	tonyviet	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-05-13 06:33:10.947	2026-05-13 06:33:10.947	\N	{}
79e5bda1-a575-4b5f-9eca-d6fe2d91ea1f	nguyentest@example.com	0901234567	$2b$10$5wEJzQbfUNshMjkETOBPDusfLTDTXUx5p3oSly2z8RURm5m2fnkYy	Nguy?n Test	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-05-28 12:00:40.893	2026-05-28 12:00:40.893	Kh�ch quen d?t qua di?n tho?i	{}
0886d71a-9289-4444-a914-a6cf76832b64	09862440@guest.banan.local	09862440	$2b$10$x1HiZs1YJAX.p3R79pduCumpD.3T3Vi1KJWAdpoGFG5WrFexVrF8a	Selftest Customer 862440	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-05-28 12:55:11.162	2026-05-28 12:55:11.162	selftest	{}
1b9a0dcc-45a6-414c-b6ac-2140ee99d84d	09189916@guest.banan.local	09189916	$2b$10$dBt56CoyZ/U1BQjl.lh84uRgOtaJT05SDpDkUC6gT00eCO/nQHktq	Selftest Customer 189916	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-05-28 12:55:51.615	2026-05-28 12:55:51.615	selftest	{}
63a01e12-3073-48e7-a620-900c0fcb2e28	09230703@guest.banan.local	09230703	$2b$10$P5Ui6Vim.6vRQsEe4yZuLujXCOPzoU3zu1QA/ijSw1aW6qF1BVstO	Selftest Customer 230703	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-05-28 13:45:10.165	2026-05-28 13:45:10.165	selftest	{}
9aa53cfd-c56a-4096-803a-f4b0d75bf805	09588291@guest.banan.local	09588291	$2b$10$1VT3xE8UvpV2aKCsI7Va7eo6fRX8Bny1ffllNkz9amW7SrjFqf6IC	Selftest Customer 588291	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-05-28 13:45:50.393	2026-05-28 13:45:50.393	selftest	{}
4e388ecf-b99c-4469-b8a9-51e355f9d4b9	guest+2b0758b3eba11af6@banan.local	0785911912	$2b$12$3kPhhvW0.VAfF.Y4BInl6.FIAlDhYuY.uu.i60SZfPduKOqp56qHK	toby	\N	CUSTOMER	SILVER	50	\N	\N	\N	2026-05-13 10:27:36.13	2026-05-17 08:58:25.597	Kh�ch VIP, th�ch b�nh �t ng?t	{VIP,low-sugar}
7858ce6f-8e76-41a7-8389-296144e78f8f	sub-merchant1@banan.local	\N	$2b$10$PdXBKWLVajozg6C0stQqa.yE3.cQctQ2WA65AUqlEVMt3ZLG4pxya	Sub Merchant 1	\N	MERCHANT_STAFF	SILVER	0	\N	aa237695-edd5-482e-aca5-54401f046b28	\N	2026-05-18 11:29:15.942	2026-05-18 11:29:15.942	\N	{}
783498ab-9459-4f48-869e-300495ef7bf9	09717640@guest.banan.local	09717640	$2b$10$UFhFP42dEzJBz2sy7N9LkOTjr0XuM29BYjkddjLRzXeU3YHsIgaly	Selftest Customer 717640	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-05-28 13:51:15.001	2026-05-28 13:51:15.001	selftest	{}
61f1af85-9347-49d4-86a3-cb858d5a0b69	guest+4dc5976e9c32ca2b@banan.local	0983154711	$2b$12$zRcjAPKaRVSuBdYv3lpKPOcoDiiI6xjzEf4w.Hw1rG7gRBBK4aAX.	Khach Vang Lai 31547	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-05-29 08:01:19.389	2026-05-29 08:01:19.389	\N	{}
90d6537e-9af8-48c1-8c44-acc1bac26dec	merchant@banan.local	\N	$2b$10$XY5.aNmkOvZGdBhaNnz7keRGgd6BOwDu/xT3hDrbEnzmxwRLQf/Wi	Lê Thánh Tôn Manager	\N	MERCHANT_OWNER	SILVER	0	\N	aa237695-edd5-482e-aca5-54401f046b28	\N	2026-05-10 06:28:37.09	2026-05-28 09:06:17.546	\N	{}
16cf4783-5c22-4ba9-9891-8a99774e5157	merchant-suvanhanh@banan.local	\N	$2b$10$nqNE4Dzz9bZvbWYtixCqqe.jJi1x/wcOV3ufg4fSZrcqA/ym3VcRa	Sư Vạn Hạnh Manager	\N	MERCHANT_OWNER	SILVER	0	\N	92ea4777-1e11-4bca-869c-3e68e3ca2e90	\N	2026-05-13 09:16:53.822	2026-05-28 09:06:17.551	\N	{}
0267cb5b-973b-4f08-95cd-6df29495a7de	merchant-ngoquanghuy@banan.local	\N	$2b$10$nqNE4Dzz9bZvbWYtixCqqe.jJi1x/wcOV3ufg4fSZrcqA/ym3VcRa	Ngô Quang Huy Manager	\N	MERCHANT_OWNER	SILVER	0	\N	36be32a7-9fac-42de-80af-cc74e30c2d03	\N	2026-05-13 09:16:53.827	2026-05-28 09:06:17.555	\N	{}
10291bfb-c4ed-463e-a626-09bed34891dd	09766498@guest.banan.local	09766498	$2b$10$S.lWLtWGljcGNkrsrhQuqe.Gq.yW7vBMstePwCfyZFX1aXpsgqsam	Selftest Customer 766498	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-05-28 13:51:21.679	2026-05-28 13:51:21.679	selftest	{}
5d28a394-1d64-4ae7-9b9b-3b6313b1686d	09189625@guest.banan.local	09189625	$2b$10$B4GBoXFr9AAbXGT4xwbGHe6L8Uxa7rHiZp5ClvrI3szbKFNL8vArq	Selftest Customer 189625	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-05-28 14:56:57.151	2026-05-28 14:56:57.151	selftest	{}
f10163ab-fd73-4441-af99-8be5d9f4cc34	0982906529065@guest.banan.local	0982906529065	$2b$10$aR7HPtGj6Cjx6q6c9sIhXu5UUaFjjUDe2NBU9bxosdR6NdcSW02De	Selftest Khach 29065	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-05-28 18:31:24.378	2026-05-28 18:31:24.378	\N	{}
29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	customer@banan.local	0900111222	$2b$10$XY5.aNmkOvZGdBhaNnz7keRGgd6BOwDu/xT3hDrbEnzmxwRLQf/Wi	Customer One	\N	CUSTOMER	GOLD	1773	\N	\N	\N	2026-05-10 06:28:37.102	2026-06-04 14:25:24.713	\N	{}
d70495ff-161a-4f2b-a817-540ca2658367	guest+e9a39deebf0b8ce1@banan.local	09862511	$2b$12$5yYLwdFsRt6OkaMHSRWCiOnXNnd8weUQnZIJ4IEBvQR729hL7Q.4C	Khach Vang Lai 625	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-06-02 08:57:34.141	2026-06-02 08:57:34.141	\N	{}
0502db59-3b85-40bc-9325-3556c61967c1	guest+a1340eebab9ba750@banan.local	098959811	$2b$12$dnM3xt894GP9vxfqY24cP.qNu6ZW.eofTOm4hwNYOIlfTJkBU3/cS	Khach Vang Lai 9598	\N	CUSTOMER	SILVER	0	\N	\N	\N	2026-06-04 14:25:17.768	2026-06-04 14:25:17.768	\N	{}
\.


ALTER TABLE public."User" ENABLE TRIGGER ALL;

--
-- Data for Name: Address; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Address" DISABLE TRIGGER ALL;

COPY public."Address" (id, "userId", label, recipient, phone, line1, line2, city, district, "postalCode", lat, lng, "isDefault", "wardCode") FROM stdin;
ac5148c5-3c5d-4bef-a9af-c990e72b99d3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	sai-gon
b0277480-193e-4398-97e8-e8c4f309bd4a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	binh-thanh
7617dd9f-ab09-4cb3-b777-b88173754a4e	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	sai-gon
ac16a33d-0aa2-40aa-b15b-cd9c3a6fa030	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	binh-thanh
c71ec1a5-e8ba-4018-8ce9-f159ae987e24	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	sai-gon
92d312c4-d2a5-4e40-92a5-040a6a066fa7	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	binh-thanh
82036ebf-39f8-42c5-a5fd-1a199803716e	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	sai-gon
fd897f6b-65c5-4681-b063-de914332f973	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	binh-thanh
0f998ac0-b554-451c-9da3-ecd18e860d63	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	sai-gon
4e7e2fc0-fdc7-4b2f-b3ad-198cb4130e33	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	binh-thanh
423839c1-3adc-49de-986e-ff63a4e6f5aa	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	sai-gon
56354e1b-8e64-4302-b4ee-793bc84b52bf	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test Customer	0900111222	123 Test Street	\N	Th�nh ph? H? Ch� Minh	\N	\N	\N	\N	f	binh-thanh
5ef039fd-3c7b-44ed-9bcd-ba7239381791	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Nguyen Van A	0900000000	12 Le Loi	\N	HCMC	\N	\N	\N	\N	f	sai-gon
243646d1-3453-485c-a6f7-230b38b3e11d	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Nguyen Van A	0900000000	12 Le Loi	\N	HCMC	\N	\N	\N	\N	f	sai-gon
855e28e6-37ba-452c-85d9-d82c2479d846	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Nguyen Van A	0900000000	12 Le Loi	\N	HCMC	\N	\N	\N	\N	f	sai-gon
406d4e5c-1fc6-4ec5-924f-618b7dc5cf7e	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Nguyen Van A	0900000000	12 Le Loi	\N	HCMC	\N	\N	\N	\N	f	sai-gon
3c3a61ce-f95c-442d-a9d1-f13a9ea753a0	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Nguyen Van A	0900000000	12 Le Loi	\N	HCMC	\N	\N	\N	\N	f	sai-gon
c98b8616-bf01-4cff-991f-3b007760c740	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Nguyen Van A	0900000000	12 Le Loi	\N	HCMC	\N	\N	\N	\N	f	sai-gon
f629518a-8d11-4a09-ac9e-be2111c6731a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Test	0900000000	12 Le Loi	\N	HCMC	\N	\N	\N	\N	f	sai-gon
2ff58fac-4430-4b50-bd37-c053daf5b09c	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Nguyen Van A	0900000000	12 Le Loi	\N	HCMC	\N	\N	\N	\N	f	sai-gon
15899ed7-96fa-41b8-babe-e32ff60494c3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Nguyen Van A	0900000000	12 Le Loi	\N	HCMC	\N	\N	\N	\N	f	sai-gon
c746e37c-9b5c-4ab2-9369-946968852a8a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Delivery	Nguyen Van A	0900000000	12 Le Loi	\N	HCMC	\N	\N	\N	\N	f	sai-gon
\.


ALTER TABLE public."Address" ENABLE TRIGGER ALL;

--
-- Data for Name: Banner; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Banner" DISABLE TRIGGER ALL;

COPY public."Banner" (id, "storeId", "imageUrl", title, "ctaUrl", "sortOrder", "isActive", "createdAt", "updatedAt") FROM stdin;
fc302620-7056-4008-af87-862f8a879c3f	aa237695-edd5-482e-aca5-54401f046b28	https://picsum.photos/1200/450	Khuyến mãi hè	\N	0	t	2026-05-18 13:14:11.12	2026-05-29 07:26:55.193
\.


ALTER TABLE public."Banner" ENABLE TRIGGER ALL;

--
-- Data for Name: Bundle; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Bundle" DISABLE TRIGGER ALL;

COPY public."Bundle" (id, "storeId", name, slug, description, "imageUrl", "priceVnd", "isActive", "isPinnedToHome", "sortOrder", "createdAt", "updatedAt") FROM stdin;
0371370b-beb3-4030-9ed7-6b6c050bffce	aa237695-edd5-482e-aca5-54401f046b28	Combo bữa sáng	combo-bua-sang	1 cookie choux + 1 mochi cho buổi sáng đầy năng lượng. Tiết kiệm 15% so với mua lẻ.	\N	110000	t	t	0	2026-05-28 14:08:40.476	2026-05-29 06:42:59.534
3c82aab1-40fb-4ee5-a821-451b991fc95b	aa237695-edd5-482e-aca5-54401f046b28	Combo trà chiều	combo-tra-chieu	3 macaron đa vị + 2 cookie choux — set hoàn hảo cho cuộc hẹn cà phê chiều với bạn bè.	\N	180000	t	t	1	2026-05-28 14:08:40.514	2026-05-29 06:42:59.603
\.


ALTER TABLE public."Bundle" ENABLE TRIGGER ALL;

--
-- Data for Name: Category; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Category" DISABLE TRIGGER ALL;

COPY public."Category" (id, name, slug, "imageUrl", "sortOrder") FROM stdin;
3e9203f3-c518-4d23-bee4-a34012c632ba	Macaron Collection	macaron-collection	\N	8
8e57654c-a12c-45b1-8576-767f9b7d52be	Cookie Choux Collection	cookie-choux-collection	\N	9
ece43c27-00d8-4c0e-8f88-787a12c0064e	Basque Burnt Cheesecake	basque-burnt-cheesecake	\N	10
5f2ce569-6588-4839-b22a-68b1a8052711	Birthday Cakes Collection	birthday-cakes	\N	11
bf1e1e65-734c-4075-aa92-deabdc1242ff	Classic Cake	classic-cake	\N	1
5a44db0a-32e2-4e98-8e9b-1c1bafbf03c4	Pudding Collection	pudding-collection	\N	2
8e113664-cb8f-42c1-b59d-cc8aec3bc64c	Can Cake Collection	can-cake-collection	\N	3
c4673729-e93e-4762-9fb0-b87241883c89	Boxes	misu-box	\N	4
e177e861-fb89-4a45-b047-adf720e05e7f	Ichigo Collection	ichigo-collection	\N	5
f9231cdb-620e-4900-8bbf-ccee1fa6d127	Daifuku Collection	daifuku-collection	\N	6
491d0db4-5b92-4877-9c27-4434d08c1a65	Mochi Collection	mochi-collection	\N	7
\.


ALTER TABLE public."Category" ENABLE TRIGGER ALL;

--
-- Data for Name: Product; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Product" DISABLE TRIGGER ALL;

COPY public."Product" (id, "storeId", "categoryId", name, slug, description, "basePrice", images, "preparationMinutes", "isAvailable", "isSeasonal", "seasonStart", "seasonEnd", "createdAt", "updatedAt", tags, "leadTimeHours", "availableDaysOfWeek", "dailyMaxQuantity", "flavorOptions", "flavorPickCount") FROM stdin;
8273baa0-eb1d-4e51-82f8-45fc325cd269	aa237695-edd5-482e-aca5-54401f046b28	bf1e1e65-734c-4075-aa92-deabdc1242ff	Nama Chocolate Cake	classic-cake-nama-chocolate-cake	Nama Chocolate Cake — from our Classic Cake.	92000.00	{https://picsum.photos/seed/classic-cake-nama-chocolate-cake/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.771	2026-05-29 06:42:58.618	{}	\N	{}	\N	{}	\N
7d6c55c8-630e-467a-b617-0bc1020cc747	aa237695-edd5-482e-aca5-54401f046b28	5a44db0a-32e2-4e98-8e9b-1c1bafbf03c4	Creme Flan	pudding-collection-creme-flan	Creme Flan — from our Pudding Collection.	55000.00	{https://picsum.photos/seed/pudding-collection-creme-flan/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.783	2026-05-29 06:42:58.663	{"Best Seller"}	\N	{}	\N	{}	\N
ae4f002f-e7ec-4022-b869-44ca482a018c	aa237695-edd5-482e-aca5-54401f046b28	5a44db0a-32e2-4e98-8e9b-1c1bafbf03c4	Matcha Pudding	pudding-collection-matcha-pudding	Matcha Pudding — from our Pudding Collection.	65000.00	{https://picsum.photos/seed/pudding-collection-matcha-pudding/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.797	2026-05-29 06:42:58.684	{"Best Seller"}	\N	{}	\N	{}	\N
97d00364-3ff8-450f-88eb-7435d92c7bc7	aa237695-edd5-482e-aca5-54401f046b28	5a44db0a-32e2-4e98-8e9b-1c1bafbf03c4	Raspberry Milk Cheezu	pudding-collection-raspberry-milk-cheezu	Raspberry Milk Cheezu — from our Pudding Collection.	65000.00	{https://picsum.photos/seed/pudding-collection-raspberry-milk-cheezu/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.801	2026-05-29 06:42:58.695	{"Best Seller"}	\N	{}	\N	{}	\N
b4a76cda-f4d7-42de-bf2c-17ee30120016	aa237695-edd5-482e-aca5-54401f046b28	8e113664-cb8f-42c1-b59d-cc8aec3bc64c	Melon Can Cake	can-cake-collection-melon-can-cake	Melon Can Cake — from our Can Cake Collection.	115000.00	{https://picsum.photos/seed/can-cake-collection-melon-can-cake/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.817	2026-05-29 06:42:58.727	{}	\N	{}	\N	{}	\N
23694f77-60cb-4c28-9807-b4acd29ae3d2	aa237695-edd5-482e-aca5-54401f046b28	8e113664-cb8f-42c1-b59d-cc8aec3bc64c	Tira-Presso Can Cake	can-cake-collection-tira-presso-can-cake	Tira-Presso Can Cake — from our Can Cake Collection.	113000.00	{https://picsum.photos/seed/can-cake-collection-tira-presso-can-cake/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.826	2026-05-29 06:42:58.745	{}	\N	{}	\N	{}	\N
444bc70e-ecd6-4732-98c9-e556d1ef8872	aa237695-edd5-482e-aca5-54401f046b28	8e113664-cb8f-42c1-b59d-cc8aec3bc64c	Matcha-Misu Can Cake	can-cake-collection-matcha-misu-can-cake	Matcha-Misu Can Cake — from our Can Cake Collection.	113000.00	{https://picsum.photos/seed/can-cake-collection-matcha-misu-can-cake/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.83	2026-05-29 06:42:58.755	{}	\N	{}	\N	{}	\N
a23c2df1-bde3-447e-ad12-db0ec573e2e0	aa237695-edd5-482e-aca5-54401f046b28	c4673729-e93e-4762-9fb0-b87241883c89	Tira-Presso Misu Box	misu-box-tira-presso-misu-box	Tira-Presso Misu Box — from our Boxes.	184000.00	{https://picsum.photos/seed/misu-box-tira-presso-misu-box/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.835	2026-05-29 06:42:58.789	{}	\N	{}	\N	{}	\N
c4928059-adb8-4201-bef4-828cb067cd78	aa237695-edd5-482e-aca5-54401f046b28	c4673729-e93e-4762-9fb0-b87241883c89	Matcha-Misu Box	misu-box-matcha-misu-box	Matcha-Misu Box — from our Boxes.	194000.00	{https://picsum.photos/seed/misu-box-matcha-misu-box/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.84	2026-05-29 06:42:58.8	{}	\N	{}	\N	{}	\N
930de0b1-460b-4ce9-9452-3a52d58cf6cf	aa237695-edd5-482e-aca5-54401f046b28	e177e861-fb89-4a45-b047-adf720e05e7f	Ichigo White Chocolate	ichigo-collection-ichigo-white-chocolate	Ichigo White Chocolate — from our Ichigo Collection.	120000.00	{https://picsum.photos/seed/ichigo-collection-ichigo-white-chocolate/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.85	2026-05-29 06:42:58.843	{}	\N	{}	\N	{}	\N
8b04c7eb-5721-4e7a-be8f-2d4f8649f03c	aa237695-edd5-482e-aca5-54401f046b28	e177e861-fb89-4a45-b047-adf720e05e7f	Ichigo Chocolate	ichigo-collection-ichigo-chocolate	Ichigo Chocolate — from our Ichigo Collection.	170000.00	{https://picsum.photos/seed/ichigo-collection-ichigo-chocolate/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.854	2026-05-29 06:42:58.854	{}	\N	{}	\N	{}	\N
076488bc-3e6b-4ea5-9f6d-90fff9dce752	aa237695-edd5-482e-aca5-54401f046b28	f9231cdb-620e-4900-8bbf-ccee1fa6d127	Kinako Daifuku	daifuku-collection-kinako-daifuku	Kinako Daifuku — from our Daifuku Collection.	73000.00	{https://picsum.photos/seed/daifuku-collection-kinako-daifuku/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.86	2026-05-29 06:42:58.888	{}	\N	{}	\N	{}	\N
646eb155-9403-4582-9a16-aab3de361ac1	aa237695-edd5-482e-aca5-54401f046b28	f9231cdb-620e-4900-8bbf-ccee1fa6d127	Matcha Daifuku	daifuku-collection-matcha-daifuku	Matcha Daifuku — from our Daifuku Collection.	80000.00	{https://picsum.photos/seed/daifuku-collection-matcha-daifuku/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.863	2026-05-29 06:42:58.899	{}	\N	{}	\N	{}	\N
7ff23984-23ac-407f-ae06-0cb3fc8e9938	aa237695-edd5-482e-aca5-54401f046b28	f9231cdb-620e-4900-8bbf-ccee1fa6d127	Ichigo Daifuku	daifuku-collection-ichigo-daifuku	Ichigo Daifuku — from our Daifuku Collection.	73000.00	{https://picsum.photos/seed/daifuku-collection-ichigo-daifuku/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.87	2026-05-29 06:42:58.925	{}	\N	{}	\N	{}	\N
eeffec67-6a81-4597-90e5-688d5d259e2f	aa237695-edd5-482e-aca5-54401f046b28	bf1e1e65-734c-4075-aa92-deabdc1242ff	Strawberry Cake	classic-cake-strawberry-cake	Strawberry Cake — from our Classic Cake.	103000.00	{https://picsum.photos/seed/classic-cake-strawberry-cake/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.726	2026-05-29 06:42:58.551	{}	\N	{}	\N	{}	\N
fe7b365f-de43-4736-b31a-7189cc15a465	aa237695-edd5-482e-aca5-54401f046b28	bf1e1e65-734c-4075-aa92-deabdc1242ff	Japanese Cheesecake	classic-cake-japanese-cheesecake	Japanese Cheesecake — from our Classic Cake.	76000.00	{https://picsum.photos/seed/classic-cake-japanese-cheesecake/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.743	2026-05-29 06:42:58.584	{}	\N	{}	\N	{}	\N
20f4ca4c-f19c-41b6-bfed-71eced88e939	aa237695-edd5-482e-aca5-54401f046b28	bf1e1e65-734c-4075-aa92-deabdc1242ff	Bear Madeleines	classic-cake-bear-madeleines	Bear Madeleines — from our Classic Cake.	54000.00	{https://picsum.photos/seed/classic-cake-bear-madeleines/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.752	2026-05-29 06:42:58.596	{}	\N	{}	\N	{}	\N
ddc41aea-1a7a-4a0f-b9af-0207b10b9613	aa237695-edd5-482e-aca5-54401f046b28	bf1e1e65-734c-4075-aa92-deabdc1242ff	Banana Walnut Bread	classic-cake-banana-walnut-bread	Banana Walnut Bread — from our Classic Cake.	59000.00	{https://picsum.photos/seed/classic-cake-banana-walnut-bread/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.757	2026-05-29 06:42:58.608	{}	\N	{}	\N	{}	\N
7f685adb-cb67-40e1-9838-6162b5d81411	aa237695-edd5-482e-aca5-54401f046b28	491d0db4-5b92-4877-9c27-4434d08c1a65	Mochi Berry Princess	mochi-collection-mochi-berry-princess	Mochi Berry Princess — from our Mochi Collection.	119000.00	{https://picsum.photos/seed/mochi-collection-mochi-berry-princess/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.875	2026-05-29 06:42:58.957	{"Best Seller"}	\N	{}	\N	{}	\N
2770fd34-7d46-49aa-b334-7f6b38002d66	aa237695-edd5-482e-aca5-54401f046b28	491d0db4-5b92-4877-9c27-4434d08c1a65	Mochi Basque Ube	mochi-collection-mochi-basque-ube	Mochi Basque Ube — from our Mochi Collection.	107000.00	{https://picsum.photos/seed/mochi-collection-mochi-basque-ube/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.883	2026-05-29 06:42:58.981	{"Best Seller"}	\N	{}	\N	{}	\N
7e19226d-e44a-4e60-83d6-cd3f8459b2c6	aa237695-edd5-482e-aca5-54401f046b28	5f2ce569-6588-4839-b22a-68b1a8052711	Signature Strawberry Cake	birthday-cakes-signature-strawberry-cake	Signature Strawberry Cake — from our Birthday Cakes Collection.	778000.00	{https://picsum.photos/seed/birthday-cakes-signature-strawberry-cake/800/600}	1440	t	f	\N	\N	2026-05-17 09:22:22.947	2026-05-29 06:42:59.179	{}	\N	{}	\N	{}	\N
0ddb05e8-5d71-49e7-894d-abc0ed2ed7df	aa237695-edd5-482e-aca5-54401f046b28	5f2ce569-6588-4839-b22a-68b1a8052711	Chocolate Strawberry Cake	birthday-cakes-chocolate-strawberry-cake	Chocolate Strawberry Cake — from our Birthday Cakes Collection.	778000.00	{https://picsum.photos/seed/birthday-cakes-chocolate-strawberry-cake/800/600}	1440	t	f	\N	\N	2026-05-17 09:22:22.952	2026-05-29 06:42:59.193	{}	\N	{}	\N	{}	\N
565b771e-03ef-4bc5-8715-71fbd61af620	aa237695-edd5-482e-aca5-54401f046b28	5f2ce569-6588-4839-b22a-68b1a8052711	Japanese Raspberry Cheesecake	birthday-cakes-japanese-raspberry-cheesecake	Japanese Raspberry Cheesecake — from our Birthday Cakes Collection.	961000.00	{https://picsum.photos/seed/birthday-cakes-japanese-raspberry-cheesecake/800/600}	1440	t	f	\N	\N	2026-05-17 09:22:22.965	2026-05-29 06:42:59.232	{}	\N	{}	\N	{}	\N
dc1220fa-88e4-45ad-a649-d54c2f9b6c75	aa237695-edd5-482e-aca5-54401f046b28	8e57654c-a12c-45b1-8576-767f9b7d52be	Original Cookie Choux	cookie-choux-collection-original-cookie-choux	Original Cookie Choux — from our Cookie Choux Collection.	60000.00	{https://picsum.photos/seed/cookie-choux-collection-original-cookie-choux/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.921	2026-05-29 06:42:59.098	{"Chef's Recommended"}	\N	{}	\N	{}	\N
8c30c3c5-4d09-4f27-87b0-4d11a9a8b3b9	aa237695-edd5-482e-aca5-54401f046b28	5f2ce569-6588-4839-b22a-68b1a8052711	Melon Whole Cake	birthday-cakes-melon-whole-cake	700g · Ø11.5 × H4.5 cm.	750000.00	{https://picsum.photos/seed/birthday-cakes-melon-whole-cake/800/600}	1440	t	f	\N	\N	2026-05-17 09:22:22.973	2026-05-29 06:42:59.254	{}	\N	{}	\N	{}	\N
59a4c7cb-2d8b-4cbe-86a8-6e14cfa8bbcf	aa237695-edd5-482e-aca5-54401f046b28	8e57654c-a12c-45b1-8576-767f9b7d52be	Matcha Cookie Choux	cookie-choux-collection-matcha-cookie-choux	Matcha Cookie Choux — from our Cookie Choux Collection.	70000.00	{https://picsum.photos/seed/cookie-choux-collection-matcha-cookie-choux/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.912	2026-05-29 06:42:59.078	{"Chef's Recommended"}	\N	{}	\N	{}	\N
468bd72b-0130-47e7-8dd4-1a32fedbf8bf	aa237695-edd5-482e-aca5-54401f046b28	ece43c27-00d8-4c0e-8f88-787a12c0064e	Basque Burnt Original	basque-burnt-cheesecake-basque-burnt-original	Basque Burnt Original — from our Basque Burnt Cheesecake.	92000.00	{https://picsum.photos/seed/basque-burnt-cheesecake-basque-burnt-original/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.934	2026-05-29 06:42:59.129	{}	\N	{}	\N	{}	\N
49d4b140-4bf4-4fe6-ad31-47ab8985cb62	aa237695-edd5-482e-aca5-54401f046b28	491d0db4-5b92-4877-9c27-4434d08c1a65	Mochi Basque Original	mochi-collection-mochi-basque-original	Mochi Basque Original — from our Mochi Collection.	107000.00	{https://picsum.photos/seed/mochi-collection-mochi-basque-original/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.887	2026-05-29 06:42:58.994	{"Best Seller"}	\N	{}	\N	{}	\N
3839a388-9536-409a-a67f-9c9eaabf67d6	aa237695-edd5-482e-aca5-54401f046b28	8e57654c-a12c-45b1-8576-767f9b7d52be	Caramel Cookie Choux	cookie-choux-collection-caramel-cookie-choux	Caramel Cookie Choux — from our Cookie Choux Collection.	70000.00	{https://picsum.photos/seed/cookie-choux-collection-caramel-cookie-choux/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.916	2026-05-29 06:42:59.088	{"Chef's Recommended"}	\N	{}	\N	{}	\N
da70beac-fe1b-4dc6-b9a3-737301afe410	aa237695-edd5-482e-aca5-54401f046b28	ece43c27-00d8-4c0e-8f88-787a12c0064e	Basque Burnt Matcha	basque-burnt-cheesecake-basque-burnt-matcha	Basque Burnt Matcha — from our Basque Burnt Cheesecake.	119000.00	{https://picsum.photos/seed/basque-burnt-cheesecake-basque-burnt-matcha/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.942	2026-05-29 06:42:59.148	{}	\N	{}	\N	{}	\N
fd92886b-c049-4be2-9074-1c6bb57814de	aa237695-edd5-482e-aca5-54401f046b28	5f2ce569-6588-4839-b22a-68b1a8052711	Matcha Strawberry Cake	birthday-cakes-matcha-strawberry-cake	Matcha Strawberry Cake — from our Birthday Cakes Collection.	972000.00	{https://picsum.photos/seed/birthday-cakes-matcha-strawberry-cake/800/600}	1440	t	f	\N	\N	2026-05-17 09:22:22.956	2026-05-29 06:42:59.21	{}	\N	{}	\N	{}	\N
70168e01-9714-46d8-83d1-33cd0e653fe3	aa237695-edd5-482e-aca5-54401f046b28	3e9203f3-c518-4d23-bee4-a34012c632ba	Set of 5 Macarons	macaron-collection-set-of-5-macarons	Tự chọn 5 vị macaron — có thể chọn nhiều cái cùng vị.	185000.00	{https://picsum.photos/seed/macaron-collection-set-of-5-macarons/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.902	2026-05-29 06:42:59.038	{}	\N	{}	\N	{Jasmine,Lemon,"Earl Grey","Bitter Chocolate","Black Sesame","Mango Passion","Raspberry Chocolate","Salted Caramel","Mint Chocolate"}	5
ccb33605-e429-45e6-afdb-caa33705e2da	aa237695-edd5-482e-aca5-54401f046b28	3e9203f3-c518-4d23-bee4-a34012c632ba	Set of 10 Macarons	macaron-collection-set-of-10-macarons	Tự chọn 10 vị macaron — có thể chọn nhiều cái cùng vị.	370000.00	{https://picsum.photos/seed/macaron-collection-set-of-10-macarons/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.906	2026-05-29 06:42:59.049	{}	\N	{}	\N	{Jasmine,Lemon,"Earl Grey","Bitter Chocolate","Black Sesame","Mango Passion","Raspberry Chocolate","Salted Caramel","Mint Chocolate"}	10
6dc58a8b-05b8-4d43-9d65-bee0e91ce9f9	aa237695-edd5-482e-aca5-54401f046b28	5f2ce569-6588-4839-b22a-68b1a8052711	Basque Burnt Original (Whole)	birthday-cakes-basque-burnt-original-whole	800g whole cake.	734000.00	{https://picsum.photos/seed/birthday-cakes-basque-burnt-original-whole/800/600}	1440	t	f	\N	\N	2026-05-18 14:49:48.741	2026-05-29 06:42:59.334	{}	\N	{}	\N	{}	\N
a32397e4-a106-4d27-81a1-fc9a067d0f54	aa237695-edd5-482e-aca5-54401f046b28	5a44db0a-32e2-4e98-8e9b-1c1bafbf03c4	Chocolate Pudding	pudding-collection-chocolate-pudding	Chocolate Pudding — from our Pudding Collection.	65000.00	{https://picsum.photos/seed/pudding-collection-chocolate-pudding/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.79	2026-05-29 06:42:58.673	{"Best Seller"}	\N	{}	\N	{}	\N
bed45760-aff4-4b05-87ff-da9e226fd8e1	aa237695-edd5-482e-aca5-54401f046b28	8e113664-cb8f-42c1-b59d-cc8aec3bc64c	Strawberry Can Cake	can-cake-collection-strawberry-can-cake	Strawberry Can Cake — from our Can Cake Collection.	113000.00	{https://picsum.photos/seed/can-cake-collection-strawberry-can-cake/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.821	2026-05-29 06:42:58.735	{}	\N	{}	\N	{}	\N
b065cf70-2089-435e-87d6-5e2b52fc3fe5	aa237695-edd5-482e-aca5-54401f046b28	f9231cdb-620e-4900-8bbf-ccee1fa6d127	Red Bean Daifuku	daifuku-collection-red-bean-daifuku	Red Bean Daifuku — from our Daifuku Collection.	75000.00	{https://picsum.photos/seed/daifuku-collection-red-bean-daifuku/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.867	2026-05-29 06:42:58.912	{}	\N	{}	\N	{}	\N
b583693d-7ca6-4aca-b2e9-ed4b6d8278a0	aa237695-edd5-482e-aca5-54401f046b28	5f2ce569-6588-4839-b22a-68b1a8052711	Mochi Berry Queen	birthday-cakes-mochi-berry-queen	Mochi Berry Queen — from our Birthday Cakes Collection.	850000.00	{https://picsum.photos/seed/birthday-cakes-mochi-berry-queen/800/600}	1440	t	f	\N	\N	2026-05-28 09:09:38.161	2026-05-29 06:42:59.241	{}	\N	{}	\N	{}	\N
6d9e7672-84cf-40ab-befa-8f0c617ee083	aa237695-edd5-482e-aca5-54401f046b28	5f2ce569-6588-4839-b22a-68b1a8052711	Basque Burnt Matcha (Whole)	birthday-cakes-basque-burnt-matcha-whole	800g whole cake.	950000.00	{https://picsum.photos/seed/birthday-cakes-basque-burnt-matcha-whole/800/600}	1440	t	f	\N	\N	2026-05-17 09:22:22.993	2026-05-29 06:42:59.303	{}	\N	{}	\N	{}	\N
0c8c3b0c-77cb-4c70-b194-6b9b7d79e91a	aa237695-edd5-482e-aca5-54401f046b28	e177e861-fb89-4a45-b047-adf720e05e7f	Ichigo Matcha	ichigo-collection-ichigo-matcha	Ichigo Matcha — from our Ichigo Collection.	170000.00	{https://picsum.photos/seed/ichigo-collection-ichigo-matcha/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.846	2026-05-29 06:42:58.831	{}	\N	{}	\N	{}	\N
dca4bbe4-f9c3-4051-9a6c-bfc74b1c8a74	aa237695-edd5-482e-aca5-54401f046b28	491d0db4-5b92-4877-9c27-4434d08c1a65	Mochi Basque Matcha	mochi-collection-mochi-basque-matcha	Mochi Basque Matcha — from our Mochi Collection.	134000.00	{https://picsum.photos/seed/mochi-collection-mochi-basque-matcha/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.88	2026-05-29 06:42:58.969	{"Best Seller"}	\N	{}	\N	{}	\N
4f5c100d-3315-4629-ac91-6fceffeb2c8d	aa237695-edd5-482e-aca5-54401f046b28	bf1e1e65-734c-4075-aa92-deabdc1242ff	Mango Passion (Summer)	mango-passion-summer	Limited summer creation: mango cremeux, passion gel, almond dacquoise.	420000.00	{}	75	f	t	2026-04-01 00:00:00	2026-09-30 00:00:00	2026-05-13 09:16:53.981	2026-05-29 06:42:59.446	{}	\N	{}	\N	{}	\N
b2073a2a-774d-42bd-9f60-79de01bcfeca	aa237695-edd5-482e-aca5-54401f046b28	3e9203f3-c518-4d23-bee4-a34012c632ba	Macaron (single)	macaron-collection-macaron-single	Pick your flavour — crisp shell, smooth ganache.	38000.00	{https://picsum.photos/seed/macaron-collection-macaron-single/800/600}	45	t	f	\N	\N	2026-05-28 09:09:38.09	2026-05-29 06:42:59.028	{}	\N	{}	\N	{}	\N
12ad7e5a-71f0-445f-843b-7af096fe288a	aa237695-edd5-482e-aca5-54401f046b28	ece43c27-00d8-4c0e-8f88-787a12c0064e	Basque Burnt Ube	basque-burnt-cheesecake-basque-burnt-ube	Basque Burnt Ube — from our Basque Burnt Cheesecake.	92000.00	{https://picsum.photos/seed/basque-burnt-cheesecake-basque-burnt-ube/800/600}	45	t	f	\N	\N	2026-05-17 09:22:22.938	2026-05-29 06:42:59.138	{}	\N	{}	\N	{}	\N
5bc02b3e-474c-4fed-af08-f9dc8caf42ef	aa237695-edd5-482e-aca5-54401f046b28	5f2ce569-6588-4839-b22a-68b1a8052711	Original Lemon Cheesecake	birthday-cakes-original-lemon-cheesecake	Original Lemon Cheesecake — from our Birthday Cakes Collection.	659000.00	{https://picsum.photos/seed/birthday-cakes-original-lemon-cheesecake/800/600}	1440	t	f	\N	\N	2026-05-17 09:22:22.961	2026-05-29 06:42:59.224	{}	\N	{}	\N	{}	\N
462abcbd-bedd-40c5-9dcf-b840d829fdbe	aa237695-edd5-482e-aca5-54401f046b28	bf1e1e65-734c-4075-aa92-deabdc1242ff	Rose Lychee Mousse	rose-lychee-mousse	Silky white-chocolate mousse layered with rose gel and lychee compote.	380000.00	{}	90	f	f	\N	\N	2026-05-13 09:16:53.891	2026-05-29 06:42:59.446	{}	\N	{}	\N	{}	\N
f0f16f3b-0b01-494a-b8b8-3cdc740bff07	aa237695-edd5-482e-aca5-54401f046b28	5f2ce569-6588-4839-b22a-68b1a8052711	Basque Burnt Ube (Whole)	birthday-cakes-basque-burnt-ube-whole	800g whole cake.	734000.00	{https://picsum.photos/seed/birthday-cakes-basque-burnt-ube-whole/800/600}	1440	t	f	\N	\N	2026-05-29 06:42:59.264	2026-05-29 06:42:59.264	{}	\N	{}	\N	{}	\N
1f8182e6-f0a1-4aa4-b920-8b509d66811f	aa237695-edd5-482e-aca5-54401f046b28	bf1e1e65-734c-4075-aa92-deabdc1242ff	Tarte au Citron	tarte-au-citron	Classic French lemon tart with torched Italian meringue.	240000.00	{}	45	f	f	\N	\N	2026-05-13 09:16:53.958	2026-05-29 06:42:59.446	{}	\N	{}	\N	{}	\N
\.


ALTER TABLE public."Product" ENABLE TRIGGER ALL;

--
-- Data for Name: ProductVariant; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."ProductVariant" DISABLE TRIGGER ALL;

COPY public."ProductVariant" (id, "productId", size, flavor, "priceDelta", "stockMode", "stockQty", "isAvailable") FROM stdin;
4fd36eef-92b1-4f96-97c2-a7787891ecd4	462abcbd-bedd-40c5-9dcf-b840d829fdbe	6"	Rose Lychee	0.00	UNLIMITED	\N	t
c904f21b-bfad-45c5-8201-3eb573fdf1bf	462abcbd-bedd-40c5-9dcf-b840d829fdbe	8"	Rose Lychee	180000.00	UNLIMITED	\N	t
cdaf2925-8d37-4ec0-8c63-c607e4805d19	1f8182e6-f0a1-4aa4-b920-8b509d66811f	Individual	Lemon	0.00	UNLIMITED	\N	t
35822d19-2b8d-4097-a802-d373a0eecab4	1f8182e6-f0a1-4aa4-b920-8b509d66811f	Whole 8"	Lemon	320000.00	UNLIMITED	\N	t
21b61875-681b-456a-bbbc-78e5a940649d	4f5c100d-3315-4629-ac91-6fceffeb2c8d	6"	Mango Passion	0.00	UNLIMITED	\N	t
67831929-4c82-42c2-8cb5-51c8c250386e	4f5c100d-3315-4629-ac91-6fceffeb2c8d	8"	Mango Passion	200000.00	UNLIMITED	\N	t
b55ca9a2-76ca-4051-8680-1222adc7450e	eeffec67-6a81-4597-90e5-688d5d259e2f	Default	Strawberry Cake	0.00	UNLIMITED	\N	t
dec18a85-8fbc-44e2-b7fc-224e1d6ddca6	fe7b365f-de43-4736-b31a-7189cc15a465	Default	Japanese Cheesecake	0.00	UNLIMITED	\N	t
8893e70e-3615-426c-8af8-2b8ae61d8a2e	20f4ca4c-f19c-41b6-bfed-71eced88e939	Default	Bear Madeleines	0.00	UNLIMITED	\N	t
c4f73fc8-4864-413a-81cf-2db30a1cd913	ddc41aea-1a7a-4a0f-b9af-0207b10b9613	Default	Banana Walnut Bread	0.00	UNLIMITED	\N	t
396f086f-f0a5-430c-936b-3bb0e3cb3879	8273baa0-eb1d-4e51-82f8-45fc325cd269	Default	Nama Chocolate Cake	0.00	UNLIMITED	\N	t
6d391d90-a22e-46db-97c4-62f6c320d144	7d6c55c8-630e-467a-b617-0bc1020cc747	Default	Creme Flan	0.00	UNLIMITED	\N	t
042b9281-0dac-4b97-b10d-6365caddc4d6	a32397e4-a106-4d27-81a1-fc9a067d0f54	Default	Chocolate Pudding	0.00	UNLIMITED	\N	t
9fea7161-43c5-4a41-9d26-8958d8bad867	ae4f002f-e7ec-4022-b869-44ca482a018c	Default	Matcha Pudding	0.00	UNLIMITED	\N	t
2521e45a-17e0-4f7b-bc55-eabb259e4a9f	97d00364-3ff8-450f-88eb-7435d92c7bc7	Default	Raspberry Milk Cheezu	0.00	UNLIMITED	\N	t
add38755-a1dd-4d86-96c4-2f473fd2a813	b4a76cda-f4d7-42de-bf2c-17ee30120016	Default	Melon Can Cake	0.00	UNLIMITED	\N	t
178cb5d8-3879-4290-8de2-f8d43103f516	bed45760-aff4-4b05-87ff-da9e226fd8e1	Default	Strawberry Can Cake	0.00	UNLIMITED	\N	t
d584bb61-0552-474a-b5b6-c01d9025cd0f	23694f77-60cb-4c28-9807-b4acd29ae3d2	Default	Tira-Presso Can Cake	0.00	UNLIMITED	\N	t
a7651e6f-62fe-48f9-8d1b-b8ac3e4c971e	444bc70e-ecd6-4732-98c9-e556d1ef8872	Default	Matcha-Misu Can Cake	0.00	UNLIMITED	\N	t
17c7dc97-31da-4805-93ea-c4805be3f551	a23c2df1-bde3-447e-ad12-db0ec573e2e0	Default	Tira-Presso Misu Box	0.00	UNLIMITED	\N	t
78a44f7a-1d08-416c-870d-9ca3e6773c67	c4928059-adb8-4201-bef4-828cb067cd78	Default	Matcha-Misu Box	0.00	UNLIMITED	\N	t
70cbd3ae-b121-4843-a4c6-dac5a1bc019f	0c8c3b0c-77cb-4c70-b194-6b9b7d79e91a	Default	Ichigo Matcha	0.00	UNLIMITED	\N	t
e46a54b8-bc92-4a0e-b173-37136a54495f	930de0b1-460b-4ce9-9452-3a52d58cf6cf	Default	Ichigo White Chocolate	0.00	UNLIMITED	\N	t
912e4a1d-66a8-432f-a878-801c5e6772b3	8b04c7eb-5721-4e7a-be8f-2d4f8649f03c	Default	Ichigo Chocolate	0.00	UNLIMITED	\N	t
75b062fd-f5f9-4920-910d-d3a13dcb5a74	076488bc-3e6b-4ea5-9f6d-90fff9dce752	Default	Kinako Daifuku	0.00	UNLIMITED	\N	t
b1e5dd91-d9af-43ea-b1de-b624b4773a47	646eb155-9403-4582-9a16-aab3de361ac1	Default	Matcha Daifuku	0.00	UNLIMITED	\N	t
10bbebd2-2969-49e4-a824-712fcd901771	b065cf70-2089-435e-87d6-5e2b52fc3fe5	Default	Red Bean Daifuku	0.00	UNLIMITED	\N	t
fd0a7c9b-e61e-4e3e-a9be-1f097fda3fcd	7ff23984-23ac-407f-ae06-0cb3fc8e9938	Default	Ichigo Daifuku	0.00	UNLIMITED	\N	t
bb0c3912-a8b6-4c1c-b129-f315ff25bd7a	7f685adb-cb67-40e1-9838-6162b5d81411	Default	Mochi Berry Princess	0.00	UNLIMITED	\N	t
c870ba77-8fca-4fc0-8207-828a70df4722	dca4bbe4-f9c3-4051-9a6c-bfc74b1c8a74	Default	Mochi Basque Matcha	0.00	UNLIMITED	\N	t
0b997b58-b84b-4178-babd-3c5eb5eb624b	2770fd34-7d46-49aa-b334-7f6b38002d66	Default	Mochi Basque Ube	0.00	UNLIMITED	\N	t
6dc99a3b-a76b-4308-bf2a-b27c757844f3	49d4b140-4bf4-4fe6-ad31-47ab8985cb62	Default	Mochi Basque Original	0.00	UNLIMITED	\N	t
09d33dc1-e32f-4482-b51b-b36df7f1051c	ccb33605-e429-45e6-afdb-caa33705e2da	Default	Set of 10 Macarons	0.00	UNLIMITED	\N	t
0ee2792d-0ecd-44bf-bd14-84fc68a13f37	59a4c7cb-2d8b-4cbe-86a8-6e14cfa8bbcf	Default	Matcha Cookie Choux	0.00	UNLIMITED	\N	t
5dc3cd0c-9718-427c-89e5-00595a818db2	3839a388-9536-409a-a67f-9c9eaabf67d6	Default	Caramel Cookie Choux	0.00	UNLIMITED	\N	t
b005e2c2-2fd0-428b-b5e0-38d21c0400f4	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	Default	Original Cookie Choux	0.00	UNLIMITED	\N	t
a81b4983-f46a-49c7-aa06-97ee9837ecf9	468bd72b-0130-47e7-8dd4-1a32fedbf8bf	Default	Basque Burnt Original	0.00	UNLIMITED	\N	t
f37f116d-bdb6-4920-84d0-139a52f52447	12ad7e5a-71f0-445f-843b-7af096fe288a	Default	Basque Burnt Ube	0.00	UNLIMITED	\N	t
d38fe45f-0713-462f-b873-7ae17f8db91f	da70beac-fe1b-4dc6-b9a3-737301afe410	Default	Basque Burnt Matcha	0.00	UNLIMITED	\N	t
7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	16cm	Strawberry	0.00	UNLIMITED	\N	t
c7bd3dbf-cee4-4021-a257-6cc965a476b2	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	18cm	Strawberry	151000.00	UNLIMITED	\N	t
8e4755aa-23d9-49ce-b322-6635b3d64f2a	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	22cm	Strawberry	734000.00	UNLIMITED	\N	t
9a8b2b90-0864-42f0-8858-cf374b52438a	70168e01-9714-46d8-83d1-33cd0e653fe3	Default	Set of 5 Macarons	0.00	UNLIMITED	\N	t
4209ab03-bb7f-49ee-8379-d45ec6f1d0e1	0ddb05e8-5d71-49e7-894d-abc0ed2ed7df	16cm	Chocolate Strawberry	0.00	UNLIMITED	\N	t
37561048-6fe6-446b-a53b-9fb868b88884	0ddb05e8-5d71-49e7-894d-abc0ed2ed7df	18cm	Chocolate Strawberry	151000.00	UNLIMITED	\N	t
51dd0d61-7c23-4d07-b246-7d0fc8e5c4ff	0ddb05e8-5d71-49e7-894d-abc0ed2ed7df	22cm	Chocolate Strawberry	734000.00	UNLIMITED	\N	t
176d6da2-4fa4-4cbe-947c-fd225a16ee7d	fd92886b-c049-4be2-9074-1c6bb57814de	16cm	Matcha Strawberry	0.00	UNLIMITED	\N	t
30b38846-2a2b-42cd-b8e9-b18315e8f7c4	fd92886b-c049-4be2-9074-1c6bb57814de	18cm	Matcha Strawberry	108000.00	UNLIMITED	\N	t
8edf57a4-8274-442c-ba91-33e37021c0ce	5bc02b3e-474c-4fed-af08-f9dc8caf42ef	16cm	Lemon Cheesecake	0.00	UNLIMITED	\N	t
c8d1feff-72d7-4cbd-8b7e-e0cdf963723a	5bc02b3e-474c-4fed-af08-f9dc8caf42ef	18cm	Lemon Cheesecake	345000.00	UNLIMITED	\N	t
a65671a7-ba66-4d8c-973a-06068346ebb2	5bc02b3e-474c-4fed-af08-f9dc8caf42ef	22cm	Lemon Cheesecake	637000.00	UNLIMITED	\N	t
a4ecf667-cd16-48bb-a6c9-d39793e269a6	565b771e-03ef-4bc5-8715-71fbd61af620	18cm	Raspberry Cheesecake	0.00	UNLIMITED	\N	t
697f0534-4b02-4565-a157-193cb3c9e3d1	565b771e-03ef-4bc5-8715-71fbd61af620	22cm	Raspberry Cheesecake	443000.00	UNLIMITED	\N	t
d19c88fd-2d2d-478d-9686-eaa0c27d0980	8c30c3c5-4d09-4f27-87b0-4d11a9a8b3b9	700g	Melon	0.00	UNLIMITED	\N	t
6c1d7368-70d5-4af9-b4a1-a0ccc43d49c9	6d9e7672-84cf-40ab-befa-8f0c617ee083	800g	Matcha	0.00	UNLIMITED	\N	t
b73d7cfc-da7f-4b1e-85ea-0627b019e47c	6dc58a8b-05b8-4d43-9d65-bee0e91ce9f9	800g	Original	0.00	UNLIMITED	\N	t
a0998b6a-17dc-40fe-8688-ea5f132f8a6d	b2073a2a-774d-42bd-9f60-79de01bcfeca	Single	Jasmine	0.00	UNLIMITED	\N	t
4673d7a8-ac8c-4e93-8cbe-5b85b3728d40	b2073a2a-774d-42bd-9f60-79de01bcfeca	Single	Lemon	0.00	UNLIMITED	\N	t
8e6cc170-b52e-4939-b743-1f2a1e695615	b2073a2a-774d-42bd-9f60-79de01bcfeca	Single	Earl Grey	0.00	UNLIMITED	\N	t
fbb495d0-a43d-45c5-a972-1f7f45555b45	b2073a2a-774d-42bd-9f60-79de01bcfeca	Single	Bitter Chocolate	0.00	UNLIMITED	\N	t
aa6a6b6f-d56c-4677-b543-f42f4d067459	b2073a2a-774d-42bd-9f60-79de01bcfeca	Single	Black Sesame	0.00	UNLIMITED	\N	t
f522e4d6-72c4-4b80-914c-0a27b0804fa5	b2073a2a-774d-42bd-9f60-79de01bcfeca	Single	Mango Passion	0.00	UNLIMITED	\N	t
eff30e50-59d2-4b67-9db0-454ad52365f8	b2073a2a-774d-42bd-9f60-79de01bcfeca	Single	Raspberry Chocolate	0.00	UNLIMITED	\N	t
09ca1d55-c0be-4a90-be7e-10628a1a8366	b2073a2a-774d-42bd-9f60-79de01bcfeca	Single	Salted Caramel	0.00	UNLIMITED	\N	t
726d01ef-0ff0-424e-884a-e3ba3e1ebfe2	b2073a2a-774d-42bd-9f60-79de01bcfeca	Single	Mint Chocolate	0.00	UNLIMITED	\N	t
b0f9ef3c-cd1d-455f-9f52-b667ec42a62e	b583693d-7ca6-4aca-b2e9-ed4b6d8278a0	16cm	Mochi Berry	0.00	UNLIMITED	\N	t
b408609b-091c-4789-b7e5-84c8952a44cf	f0f16f3b-0b01-494a-b8b8-3cdc740bff07	800g	Ube	0.00	UNLIMITED	\N	t
\.


ALTER TABLE public."ProductVariant" ENABLE TRIGGER ALL;

--
-- Data for Name: BundleItem; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."BundleItem" DISABLE TRIGGER ALL;

COPY public."BundleItem" (id, "bundleId", "productId", "variantId", quantity) FROM stdin;
a172e307-135e-4763-9609-06ff3d9829cf	0371370b-beb3-4030-9ed7-6b6c050bffce	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	\N	1
9dc30eab-b0f6-4f8f-a2be-3fe5ff0b3c84	0371370b-beb3-4030-9ed7-6b6c050bffce	49d4b140-4bf4-4fe6-ad31-47ab8985cb62	\N	1
5e908ab9-c5cd-4c72-87b1-8c0a8dc575bc	3c82aab1-40fb-4ee5-a821-451b991fc95b	70168e01-9714-46d8-83d1-33cd0e653fe3	\N	1
86db9f35-f257-4751-9afd-b21f5eab9592	3c82aab1-40fb-4ee5-a821-451b991fc95b	59a4c7cb-2d8b-4cbe-86a8-6e14cfa8bbcf	\N	2
\.


ALTER TABLE public."BundleItem" ENABLE TRIGGER ALL;

--
-- Data for Name: Collection; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Collection" DISABLE TRIGGER ALL;

COPY public."Collection" (id, "storeId", name, slug, description, "imageUrl", "isPinnedToHome", "sortOrder", "isActive", "createdAt", "updatedAt") FROM stdin;
037f8f4c-2ce8-4637-a316-b617703bc528	aa237695-edd5-482e-aca5-54401f046b28	Classic Cake	home-classic-cake	Classic Cake.	\N	f	2	t	2026-05-18 14:49:48.325	2026-05-29 06:42:58.628
840c4aa5-c34d-4252-a5be-164288aed1ce	aa237695-edd5-482e-aca5-54401f046b28	Pudding Collection	home-pudding-collection	Our silkiest puddings — a customer favourite.	\N	t	3	t	2026-05-28 09:09:37.992	2026-05-29 06:42:58.705
fc49d078-94fd-4079-91e5-91be721b72a9	aa237695-edd5-482e-aca5-54401f046b28	Can Cake Collection	home-can-cake-collection	Can Cake Collection.	\N	f	4	t	2026-05-18 14:49:48.41	2026-05-29 06:42:58.765
85995fe5-8030-4c65-95b8-ad97d6c64180	aa237695-edd5-482e-aca5-54401f046b28	Boxes	home-misu-box	Boxes.	\N	f	5	t	2026-05-18 14:49:48.439	2026-05-29 06:42:58.81
cb3f8c39-81e4-4a60-bc72-6a756c83aa60	aa237695-edd5-482e-aca5-54401f046b28	Ichigo Collection	home-ichigo-collection	Ichigo Collection.	\N	f	6	t	2026-05-18 14:49:48.461	2026-05-29 06:42:58.865
7f07aefc-232b-4576-b291-eeefbf2b42d9	aa237695-edd5-482e-aca5-54401f046b28	Daifuku Collection	home-daifuku-collection	Daifuku Collection.	\N	f	7	t	2026-05-18 14:49:48.493	2026-05-29 06:42:58.936
2a89cadc-dea5-4a9f-81b6-7ef72d04cba1	aa237695-edd5-482e-aca5-54401f046b28	Mochi Collection	home-mochi-collection	Pillowy mochi creations — flying off the shelves.	\N	t	8	t	2026-05-28 09:09:38.084	2026-05-29 06:42:59.005
9307b437-29cf-4d52-bb7a-0e74adaa9be8	aa237695-edd5-482e-aca5-54401f046b28	Macaron Collection	home-macaron-collection	Macaron Collection.	\N	f	9	t	2026-05-18 14:49:48.575	2026-05-29 06:42:59.059
5e3f5610-b9d0-4feb-bcc4-65b9815dcc39	aa237695-edd5-482e-aca5-54401f046b28	Cookie Choux Collection	home-cookie-choux-collection	The pastry chef's pick — crackly choux, lush cream.	\N	t	10	t	2026-05-17 09:22:22.925	2026-05-29 06:42:59.108
9ff8f93e-a608-4828-9168-e869ee51a02b	aa237695-edd5-482e-aca5-54401f046b28	Basque Burnt Cheesecake	home-basque-burnt-cheesecake	Basque Burnt Cheesecake.	\N	f	11	t	2026-05-18 14:49:48.661	2026-05-29 06:42:59.157
6f1bd1ab-0ea9-46e8-b020-d3ef66dacd17	aa237695-edd5-482e-aca5-54401f046b28	Birthday Cakes Collection	home-birthday-cakes	Whole cakes for celebrations — order ahead.	\N	f	12	t	2026-05-18 14:49:48.757	2026-05-29 06:42:59.378
\.


ALTER TABLE public."Collection" ENABLE TRIGGER ALL;

--
-- Data for Name: CollectionItem; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."CollectionItem" DISABLE TRIGGER ALL;

COPY public."CollectionItem" (id, "collectionId", "productId", "sortOrder", "createdAt") FROM stdin;
a1550836-a2b3-4402-9357-673cff9e0b17	037f8f4c-2ce8-4637-a316-b617703bc528	eeffec67-6a81-4597-90e5-688d5d259e2f	0	2026-05-29 06:42:58.642
3e6e71e9-5d48-4b3d-ae4e-c9ddceba6d91	037f8f4c-2ce8-4637-a316-b617703bc528	fe7b365f-de43-4736-b31a-7189cc15a465	1	2026-05-29 06:42:58.642
db0a03aa-85e2-438d-b3f7-d1e8f67747fe	037f8f4c-2ce8-4637-a316-b617703bc528	20f4ca4c-f19c-41b6-bfed-71eced88e939	2	2026-05-29 06:42:58.642
0df92b87-ced3-4df9-85d3-eca469df25f5	037f8f4c-2ce8-4637-a316-b617703bc528	ddc41aea-1a7a-4a0f-b9af-0207b10b9613	3	2026-05-29 06:42:58.642
c403df68-3d67-48a6-a27f-0a9ecd389337	037f8f4c-2ce8-4637-a316-b617703bc528	8273baa0-eb1d-4e51-82f8-45fc325cd269	4	2026-05-29 06:42:58.642
3ac63778-9cc6-4d6c-9932-87da9880c882	840c4aa5-c34d-4252-a5be-164288aed1ce	7d6c55c8-630e-467a-b617-0bc1020cc747	0	2026-05-29 06:42:58.715
24e04e8c-9cfc-4849-b43b-34ba3a0ef843	840c4aa5-c34d-4252-a5be-164288aed1ce	a32397e4-a106-4d27-81a1-fc9a067d0f54	1	2026-05-29 06:42:58.715
c8b2d69c-f5b5-47eb-baff-483bf72e63ba	840c4aa5-c34d-4252-a5be-164288aed1ce	ae4f002f-e7ec-4022-b869-44ca482a018c	2	2026-05-29 06:42:58.715
38ccf0b5-46da-4c6c-a0eb-485348badb78	840c4aa5-c34d-4252-a5be-164288aed1ce	97d00364-3ff8-450f-88eb-7435d92c7bc7	3	2026-05-29 06:42:58.715
01d8908d-32d8-42b3-ac8c-577e78436278	fc49d078-94fd-4079-91e5-91be721b72a9	b4a76cda-f4d7-42de-bf2c-17ee30120016	0	2026-05-29 06:42:58.774
b784a13f-d7a1-46f1-af99-b2faabc51e52	fc49d078-94fd-4079-91e5-91be721b72a9	bed45760-aff4-4b05-87ff-da9e226fd8e1	1	2026-05-29 06:42:58.774
17778b42-af62-4b7f-b951-1ad471d4dc2a	fc49d078-94fd-4079-91e5-91be721b72a9	23694f77-60cb-4c28-9807-b4acd29ae3d2	2	2026-05-29 06:42:58.774
c5083548-07c2-4d9f-82f2-d214c53ab0cc	fc49d078-94fd-4079-91e5-91be721b72a9	444bc70e-ecd6-4732-98c9-e556d1ef8872	3	2026-05-29 06:42:58.774
4f88cf79-09f5-4d0c-968b-6518b00d6559	85995fe5-8030-4c65-95b8-ad97d6c64180	a23c2df1-bde3-447e-ad12-db0ec573e2e0	0	2026-05-29 06:42:58.819
54fdaca2-1be6-47fa-b016-13060c86198e	85995fe5-8030-4c65-95b8-ad97d6c64180	c4928059-adb8-4201-bef4-828cb067cd78	1	2026-05-29 06:42:58.819
c29af506-e28a-4e89-ad0e-8e293baf0696	cb3f8c39-81e4-4a60-bc72-6a756c83aa60	0c8c3b0c-77cb-4c70-b194-6b9b7d79e91a	0	2026-05-29 06:42:58.873
bfbd553b-e208-47cb-a3b2-3d9ef64cf16b	cb3f8c39-81e4-4a60-bc72-6a756c83aa60	930de0b1-460b-4ce9-9452-3a52d58cf6cf	1	2026-05-29 06:42:58.873
35183ac3-8213-41f8-a844-8cb14d8136e2	cb3f8c39-81e4-4a60-bc72-6a756c83aa60	8b04c7eb-5721-4e7a-be8f-2d4f8649f03c	2	2026-05-29 06:42:58.873
3d802c05-fbe4-46bc-abdb-cf711ffa9b64	7f07aefc-232b-4576-b291-eeefbf2b42d9	076488bc-3e6b-4ea5-9f6d-90fff9dce752	0	2026-05-29 06:42:58.945
4365e183-39f8-45fe-b6ca-28ef26fbd899	7f07aefc-232b-4576-b291-eeefbf2b42d9	646eb155-9403-4582-9a16-aab3de361ac1	1	2026-05-29 06:42:58.945
c11ef9d7-5f2b-4a68-920e-0c214410451c	7f07aefc-232b-4576-b291-eeefbf2b42d9	b065cf70-2089-435e-87d6-5e2b52fc3fe5	2	2026-05-29 06:42:58.945
9e32f649-1b03-4d81-b3d3-aeaa5a439ed0	7f07aefc-232b-4576-b291-eeefbf2b42d9	7ff23984-23ac-407f-ae06-0cb3fc8e9938	3	2026-05-29 06:42:58.945
6ffd1a4a-0351-46cf-83a3-1e4f1e291f56	2a89cadc-dea5-4a9f-81b6-7ef72d04cba1	7f685adb-cb67-40e1-9838-6162b5d81411	0	2026-05-29 06:42:59.013
1076c908-66fb-4bc6-a0c4-574158a822cc	2a89cadc-dea5-4a9f-81b6-7ef72d04cba1	dca4bbe4-f9c3-4051-9a6c-bfc74b1c8a74	1	2026-05-29 06:42:59.013
5853061e-078e-4541-a110-7f38b3b522c1	2a89cadc-dea5-4a9f-81b6-7ef72d04cba1	2770fd34-7d46-49aa-b334-7f6b38002d66	2	2026-05-29 06:42:59.013
b7f5d4c0-76ac-4960-9383-526a792a1882	2a89cadc-dea5-4a9f-81b6-7ef72d04cba1	49d4b140-4bf4-4fe6-ad31-47ab8985cb62	3	2026-05-29 06:42:59.013
7eae9ce8-f4c7-480f-8233-888d3905f81c	9307b437-29cf-4d52-bb7a-0e74adaa9be8	b2073a2a-774d-42bd-9f60-79de01bcfeca	0	2026-05-29 06:42:59.068
53afb79e-7a00-4ab1-92fd-985fbdffaa2a	9307b437-29cf-4d52-bb7a-0e74adaa9be8	70168e01-9714-46d8-83d1-33cd0e653fe3	1	2026-05-29 06:42:59.068
17c91217-ae41-4c9b-932c-521a1316133b	9307b437-29cf-4d52-bb7a-0e74adaa9be8	ccb33605-e429-45e6-afdb-caa33705e2da	2	2026-05-29 06:42:59.068
da604b02-8aa0-469a-ac73-313f5460e54d	5e3f5610-b9d0-4feb-bcc4-65b9815dcc39	59a4c7cb-2d8b-4cbe-86a8-6e14cfa8bbcf	0	2026-05-29 06:42:59.117
c3def298-658e-43c7-8fd6-ec10a946f62b	5e3f5610-b9d0-4feb-bcc4-65b9815dcc39	3839a388-9536-409a-a67f-9c9eaabf67d6	1	2026-05-29 06:42:59.117
2edd8412-5c3f-43b6-8906-d6b493ecfcb3	5e3f5610-b9d0-4feb-bcc4-65b9815dcc39	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	2	2026-05-29 06:42:59.117
9973d54f-47aa-41af-84ae-64c01e8e24e5	9ff8f93e-a608-4828-9168-e869ee51a02b	468bd72b-0130-47e7-8dd4-1a32fedbf8bf	0	2026-05-29 06:42:59.164
a4712f41-a324-4e1e-92b6-9fb0c1c4bc4e	9ff8f93e-a608-4828-9168-e869ee51a02b	12ad7e5a-71f0-445f-843b-7af096fe288a	1	2026-05-29 06:42:59.164
23da7935-3954-4394-8e4a-03d9d20dfdb7	9ff8f93e-a608-4828-9168-e869ee51a02b	da70beac-fe1b-4dc6-b9a3-737301afe410	2	2026-05-29 06:42:59.164
0dcf6cf3-27b7-4a77-bd28-b6bec7c06121	6f1bd1ab-0ea9-46e8-b020-d3ef66dacd17	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	0	2026-05-29 06:42:59.411
decafa62-69e2-48ba-b387-489b471e7faf	6f1bd1ab-0ea9-46e8-b020-d3ef66dacd17	0ddb05e8-5d71-49e7-894d-abc0ed2ed7df	1	2026-05-29 06:42:59.411
bf90bd93-2fc1-4b52-bc1b-b994410eb349	6f1bd1ab-0ea9-46e8-b020-d3ef66dacd17	fd92886b-c049-4be2-9074-1c6bb57814de	2	2026-05-29 06:42:59.411
5ffe8920-58ce-44e0-8cfe-3450dbd72260	6f1bd1ab-0ea9-46e8-b020-d3ef66dacd17	5bc02b3e-474c-4fed-af08-f9dc8caf42ef	3	2026-05-29 06:42:59.411
0e6655ce-8de9-4893-a1df-696021e22165	6f1bd1ab-0ea9-46e8-b020-d3ef66dacd17	565b771e-03ef-4bc5-8715-71fbd61af620	4	2026-05-29 06:42:59.411
d35f4c82-4161-46d8-b4b1-a10d7fe7f676	6f1bd1ab-0ea9-46e8-b020-d3ef66dacd17	b583693d-7ca6-4aca-b2e9-ed4b6d8278a0	5	2026-05-29 06:42:59.411
99385de6-74f5-4389-85da-f7bcc516d993	6f1bd1ab-0ea9-46e8-b020-d3ef66dacd17	8c30c3c5-4d09-4f27-87b0-4d11a9a8b3b9	6	2026-05-29 06:42:59.411
cf09a2dd-a348-4ede-85c7-f5410a0abc9e	6f1bd1ab-0ea9-46e8-b020-d3ef66dacd17	f0f16f3b-0b01-494a-b8b8-3cdc740bff07	7	2026-05-29 06:42:59.411
4bcd4489-8a2e-47c9-9225-b830984e8e2d	6f1bd1ab-0ea9-46e8-b020-d3ef66dacd17	6d9e7672-84cf-40ab-befa-8f0c617ee083	8	2026-05-29 06:42:59.411
0098c91c-918e-4e97-9bbe-ebdb47505518	6f1bd1ab-0ea9-46e8-b020-d3ef66dacd17	6dc58a8b-05b8-4d43-9d65-bee0e91ce9f9	9	2026-05-29 06:42:59.411
\.


ALTER TABLE public."CollectionItem" ENABLE TRIGGER ALL;

--
-- Data for Name: Coupon; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Coupon" DISABLE TRIGGER ALL;

COPY public."Coupon" (id, code, type, value, "minSubtotal", "startsAt", "endsAt", "maxRedemptions", redemptions, "perUserLimit", "isActive", "storeId", label, "createdAt") FROM stdin;
2ef749e4-d338-4bad-900a-369045824a98	WELCOME10	PERCENT	10.00	\N	2024-01-01 00:00:00	2099-12-31 00:00:00	\N	0	1	t	\N	\N	2026-05-17 09:04:27.446
1cb530db-637a-4c65-8b0f-a6be73ede8ca	BANAN20K	FIXED	20000.00	100000.00	2024-01-01 00:00:00	2099-12-31 00:00:00	\N	0	5	t	\N	\N	2026-05-17 09:04:27.446
3f1c5e40-10f6-40de-8dc4-a8cea88b7c9e	FREEDELIV	FREE_DELIVERY	0.00	\N	2024-01-01 00:00:00	2099-12-31 00:00:00	\N	0	3	t	\N	\N	2026-05-17 09:04:27.446
f1e36061-59e1-4faa-bb4a-5039e62e9b42	BANAN-3E9CE3E9	PERCENT	15.00	\N	2026-05-17 08:58:25.683	2026-06-16 08:58:25.683	1	0	1	t	\N	\N	2026-05-17 09:04:27.446
4b02166a-41f2-4064-a3fd-aa72427a56fd	SUMMER25	PERCENT	25.00	\N	2026-05-16 00:00:00	2026-06-30 00:00:00	100	0	1	t	aa237695-edd5-482e-aca5-54401f046b28	Summer promo	2026-05-17 09:08:21.621
6326c1cb-6d1c-4915-92a4-ee885cad6ac6	SELFTEST29065	PERCENT	10.00	\N	2026-05-29 11:00:00	2026-06-04 00:00:00	\N	0	1	f	aa237695-edd5-482e-aca5-54401f046b28	Selftest 10%	2026-05-28 18:31:23.229
\.


ALTER TABLE public."Coupon" ENABLE TRIGGER ALL;

--
-- Data for Name: Order; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Order" DISABLE TRIGGER ALL;

COPY public."Order" (id, code, "customerId", "storeId", "kitchenId", "fulfillmentType", "scheduledFor", "addressId", status, "kitchenStatus", currency, subtotal, "deliveryFee", "pointsRedeemed", "pointsDiscount", "couponId", "couponDiscount", total, "customMessage", notes, "createdAt", "updatedAt", "dueSoonNotifiedAt", "invoiceAddress", "invoiceCompanyName", "invoiceEmail", "invoiceFileUrl", "invoiceIssuedAt", "invoiceTaxId", "requestVatInvoice", "giftCardAmountVnd", "giftCardCode") FROM stdin;
f0a0d840-5792-4d71-bb97-b1bfb80ed10d	BAN-2026-LBY7QQ	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	COMPLETED	\N	VND	620000.00	0.00	0	0.00	\N	0.00	620000.00	\N	\N	2026-05-10 09:25:28.332	2026-05-13 09:24:08.516	\N	\N	\N	\N	\N	\N	\N	f	0	\N
bda681ec-e669-4029-b6f6-31f823328307	BAN-2026-8FJ8TX	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	CANCELLED	\N	VND	620000.00	0.00	0	0.00	\N	0.00	620000.00	\N	\N	2026-05-10 09:56:42.836	2026-05-13 09:24:08.516	\N	\N	\N	\N	\N	\N	\N	f	0	\N
89fab936-1cc9-4b40-b4c5-be0c4b54109f	BAN-2026-673YWE	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	CANCELLED	\N	VND	620000.00	0.00	0	0.00	\N	0.00	620000.00	\N	\N	2026-05-10 09:57:46.339	2026-05-13 09:24:08.516	\N	\N	\N	\N	\N	\N	\N	f	0	\N
c2a3e00d-5319-4144-84b4-eff3d58b0659	BAN-2026-YTLYFE	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	PENDING	\N	VND	420000.00	0.00	0	0.00	\N	0.00	420000.00	\N	\N	2026-05-11 10:46:38.467	2026-05-13 09:24:08.516	\N	\N	\N	\N	\N	\N	\N	f	0	\N
d8789680-e784-4186-8c35-27863524ca68	BAN-2026-QF3Y4K	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	PENDING	\N	VND	240000.00	0.00	0	0.00	\N	0.00	240000.00	\N	\N	2026-05-11 10:49:59.32	2026-05-13 09:24:08.516	\N	\N	\N	\N	\N	\N	\N	f	0	\N
048a1b04-4f67-4b24-9056-5fa16c1d0b0f	BAN-2026-HP8ZH3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	PENDING	\N	VND	420000.00	0.00	0	0.00	\N	0.00	420000.00	\N	\N	2026-05-11 10:51:09.58	2026-05-13 09:24:08.516	\N	\N	\N	\N	\N	\N	\N	f	0	\N
2e5da661-e48b-4e68-b7cd-5b5397bc3d54	BAN-2026-VX6M52	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	PENDING	\N	VND	420000.00	0.00	0	0.00	\N	0.00	420000.00	\N	\N	2026-05-13 08:14:42.681	2026-05-13 09:24:08.516	\N	\N	\N	\N	\N	\N	\N	f	0	\N
0cf1fecb-9856-447c-8a88-3bd8adff8bc9	BAN-2026-FXCU2J	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	PICKUP	2026-05-29 13:05:00	\N	COMPLETED	READY_DISPATCH	VND	240000.00	0.00	0	0.00	\N	0.00	240000.00	\N	\N	2026-05-13 08:11:07.785	2026-05-13 09:24:08.516	\N	\N	\N	\N	\N	\N	\N	f	0	\N
322fdd05-ee34-4cbe-8f99-e5eb37ed5314	BAN-2026-AYBNAF	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-30 11:11:00	\N	COMPLETED	\N	VND	240000.00	0.00	0	0.00	\N	0.00	240000.00	\N	\N	2026-05-13 08:11:23.656	2026-05-13 09:35:54.625	\N	\N	\N	\N	\N	\N	\N	f	0	\N
81d4c479-c7be-46fd-8181-6dc4616541bb	BAN-2026-PSNK4N	3293c2bf-4ceb-4e45-8597-61bad26a4bad	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	ACCEPTED	\N	VND	240000.00	0.00	0	0.00	\N	0.00	240000.00	\N	\N	2026-05-13 06:33:43.306	2026-05-13 09:36:01.964	\N	\N	\N	\N	\N	\N	\N	f	0	\N
cff6b826-0ffa-4458-96bb-ca30dd0e310b	BAN-2026-3GXMGC	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	PENDING	\N	VND	240000.00	0.00	0	0.00	\N	0.00	240000.00	\N	\N	2026-05-13 10:23:58.049	2026-05-13 10:23:58.049	\N	\N	\N	\N	\N	\N	\N	f	0	\N
2d79c95b-ce16-459d-91cf-53d1f39edc4a	BAN-2026-RKHUZC	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	PICKUP	\N	\N	COMPLETED	READY_DISPATCH	VND	240000.00	0.00	0	0.00	\N	0.00	240000.00	\N	\N	2026-05-13 09:57:47.535	2026-05-13 10:43:06.565	\N	\N	\N	\N	\N	\N	\N	f	0	\N
36cb2b2b-f0e8-44b5-bc59-23931e320913	BAN-2026-UHW22V	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	ACCEPTED	\N	VND	240000.00	0.00	0	0.00	\N	0.00	240000.00	\N	\N	2026-05-13 10:27:36.161	2026-05-14 05:06:02.381	\N	\N	\N	\N	\N	\N	\N	f	0	\N
060470be-e651-4d99-b519-9ea5491effd9	BAN-2026-HK7TLK	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	PICKUP	\N	\N	COMPLETED	READY_DISPATCH	VND	240000.00	0.00	0	0.00	\N	0.00	240000.00	\N	\N	2026-05-14 05:07:49.74	2026-05-14 05:09:19.661	\N	\N	\N	\N	\N	\N	\N	f	0	\N
c47b501f-763d-4a2d-bf4b-2377d8c39b6f	BAN-2026-BLMXZS	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	COMPLETED	\N	VND	420000.00	0.00	0	0.00	\N	0.00	420000.00	\N	\N	2026-05-15 10:51:49.31	2026-05-15 10:52:04.206	\N	\N	\N	\N	\N	\N	\N	f	0	\N
54081945-a072-4dc5-924c-60aa005a4344	BAN-2026-LLLP8B	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	COMPLETED	\N	VND	560000.00	0.00	0	0.00	\N	0.00	560000.00	\N	\N	2026-05-15 10:56:12.951	2026-05-15 10:56:27.365	\N	\N	\N	\N	\N	\N	\N	f	0	\N
a2476e33-44d3-4c2b-ad4d-798099f6522c	BAN-2026-CCNMLX	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	\N	\N	COMPLETED	\N	VND	240000.00	0.00	0	0.00	\N	0.00	240000.00	\N	\N	2026-05-15 11:00:51.786	2026-05-15 11:01:31.116	\N	\N	\N	\N	\N	\N	\N	f	0	\N
0a6067cb-cfb2-4be0-b5c7-4d98fe27129e	BAN-2026-J9LFFY	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 08:45:34	b0277480-193e-4398-97e8-e8c4f309bd4a	PENDING	\N	VND	60000.00	30000.00	0	3000.00	\N	0.00	87000.00	\N	2. Std + other ward (binh-thanh)	2026-05-27 04:45:34.22	2026-05-27 06:50:00.094	2026-05-27 06:50:00.017	\N	\N	\N	\N	\N	\N	f	0	\N
c573a2c0-ab99-4fe5-a4fb-6807a578688c	BAN-2026-HX6RBH	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 08:45:34	7617dd9f-ab09-4cb3-b777-b88173754a4e	PENDING	\N	VND	778000.00	30000.00	0	38900.00	\N	0.00	769100.00	\N	3. Bday + same ward (sai-gon)	2026-05-27 04:45:35.06	2026-05-27 06:50:00.103	2026-05-27 06:50:00.017	\N	\N	\N	\N	\N	\N	f	0	\N
71fa0429-dd11-429a-8d10-6444d48180df	BAN-2026-DX7B92	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 08:45:35	ac16a33d-0aa2-40aa-b15b-cd9c3a6fa030	PENDING	\N	VND	778000.00	70000.00	0	38900.00	\N	0.00	809100.00	\N	4. Bday + other ward (binh-thanh)	2026-05-27 04:45:36.128	2026-05-27 06:50:00.112	2026-05-27 06:50:00.017	\N	\N	\N	\N	\N	\N	f	0	\N
1e848d09-56e4-4f97-892a-491cbed7c625	BAN-2026-KRJSNA	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-27 08:45:37	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	5. Pickup (no delivery fee)	2026-05-27 04:45:37.144	2026-05-27 06:50:00.121	2026-05-27 06:50:00.017	\N	\N	\N	\N	\N	\N	f	0	\N
06d2dfdf-83cb-4485-95f4-e83287e72c6f	BAN-2026-QCMKBJ	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 10:23:27	c71ec1a5-e8ba-4018-8ce9-f159ae987e24	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	1. Std + same ward (sai-gon)	2026-05-27 06:23:28.109	2026-05-27 08:25:00.155	2026-05-27 08:25:00.009	\N	\N	\N	\N	\N	\N	f	0	\N
8b0aaca7-6e78-4010-b988-cc241b9f0e34	BAN-2026-GFKZ64	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 10:23:28	92d312c4-d2a5-4e40-92a5-040a6a066fa7	PENDING	\N	VND	60000.00	30000.00	0	3000.00	\N	0.00	87000.00	\N	2. Std + other ward (binh-thanh)	2026-05-27 06:23:29.036	2026-05-27 08:25:00.247	2026-05-27 08:25:00.009	\N	\N	\N	\N	\N	\N	f	0	\N
3c3a9c52-ccfd-4669-ae34-b8c1ab660813	BAN-2026-VNGSTK	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 10:23:29	82036ebf-39f8-42c5-a5fd-1a199803716e	PENDING	\N	VND	778000.00	30000.00	0	38900.00	\N	0.00	769100.00	\N	3. Bday + same ward (sai-gon)	2026-05-27 06:23:30.033	2026-05-27 08:25:00.27	2026-05-27 08:25:00.009	\N	\N	\N	\N	\N	\N	f	0	\N
ea013a43-7376-4e96-aaa1-04eee039bf28	BAN-2026-9DFQ5J	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 10:23:30	fd897f6b-65c5-4681-b063-de914332f973	PENDING	\N	VND	778000.00	70000.00	0	38900.00	\N	0.00	809100.00	\N	4. Bday + other ward (binh-thanh)	2026-05-27 06:23:31.183	2026-05-27 08:25:00.285	2026-05-27 08:25:00.009	\N	\N	\N	\N	\N	\N	f	0	\N
7fd35beb-5d8a-4f76-b6f8-125abe027dc2	BAN-2026-TEDTZ3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-27 10:23:32	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	5. Pickup (no delivery fee)	2026-05-27 06:23:32.157	2026-05-27 08:25:00.304	2026-05-27 08:25:00.009	\N	\N	\N	\N	\N	\N	f	0	\N
360b1f6b-906b-49db-b7e3-67541b684874	BAN-2026-TLQH3L	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 10:23:57	0f998ac0-b554-451c-9da3-ecd18e860d63	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	1. Std + same ward (sai-gon)	2026-05-27 06:23:57.573	2026-05-27 08:25:00.319	2026-05-27 08:25:00.009	\N	\N	\N	\N	\N	\N	f	0	\N
f4221321-a57b-4002-a94f-0d93688d71c1	BAN-2026-W85P6L	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 10:23:58	4e7e2fc0-fdc7-4b2f-b3ad-198cb4130e33	PENDING	\N	VND	60000.00	30000.00	0	3000.00	\N	0.00	87000.00	\N	2. Std + other ward (binh-thanh)	2026-05-27 06:23:58.403	2026-05-27 08:25:00.328	2026-05-27 08:25:00.009	\N	\N	\N	\N	\N	\N	f	0	\N
71e6adfe-e78e-454c-adb3-bee43493df48	BAN-2026-B7W3FW	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 10:23:59	423839c1-3adc-49de-986e-ff63a4e6f5aa	PENDING	\N	VND	778000.00	30000.00	0	38900.00	\N	0.00	769100.00	\N	3. Bday + same ward (sai-gon)	2026-05-27 06:23:59.272	2026-05-27 08:25:00.336	2026-05-27 08:25:00.009	\N	\N	\N	\N	\N	\N	f	0	\N
7da53799-e88f-459c-b0ec-c988e7d8793a	BAN-2026-MWP96E	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 08:45:33	ac5148c5-3c5d-4bef-a9af-c990e72b99d3	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	1. Std + same ward (sai-gon)	2026-05-27 04:45:33.348	2026-05-27 06:50:00.071	2026-05-27 06:50:00.017	\N	\N	\N	\N	\N	\N	f	0	\N
415d8f50-24cc-47ad-a356-e65c5a126a36	BAN-2026-ZPY4FT	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-27 10:24:00	56354e1b-8e64-4302-b4ee-793bc84b52bf	PENDING	\N	VND	778000.00	70000.00	0	38900.00	\N	0.00	809100.00	\N	4. Bday + other ward (binh-thanh)	2026-05-27 06:24:00.257	2026-05-27 08:25:00.347	2026-05-27 08:25:00.009	\N	\N	\N	\N	\N	\N	f	0	\N
930a41c4-0cd0-44a3-80d0-f1dec0a7987d	BAN-2026-D7FJ7Q	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-27 10:24:00	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	5. Pickup (no delivery fee)	2026-05-27 06:24:01.174	2026-05-27 08:25:00.359	2026-05-27 08:25:00.009	\N	\N	\N	\N	\N	\N	f	0	\N
f416ccc5-c756-4486-a4f6-21000213936e	BAN-2026-XHJESQ	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-28 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-27 07:07:05.829	2026-05-28 09:00:00.019	2026-05-28 09:00:00.002	123 Test, B?n Ngh�	C�ng ty TNHH Test	finance@test.com	https://example.com/invoices/BAN-2026-XHJESQ.pdf	2026-05-27 07:18:56.302	0123456789	t	0	\N
6ac99d21-6d61-4c1b-9bc3-8f222cfd44f3	BAN-2026-UYQL7Z	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-05-28 10:33:52.977	2026-06-02 08:25:00.19	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
c1bd6aa5-4b8c-4905-ab85-d0f6116c26d2	BAN-2026-7CGUKX	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-05-28 10:36:25.565	2026-06-02 08:25:00.195	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
aabdd124-5231-4e59-9662-5eabcbb12a35	BAN-2026-V4TJYZ	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 10:36:26.491	2026-06-02 08:25:00.2	2026-06-02 08:25:00.033	123 Test Street, P. B?n Ngh�	Selftest Co.	selftest@example.com	\N	\N	0123456789	t	0	\N
391c5fe3-1d1e-4faa-951a-53d408672097	BAN-2026-P35VMG	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-05-28 12:55:06.331	2026-06-02 08:25:00.206	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
da82ec7c-c33d-42ef-9e7c-11407ad56658	BAN-2026-4FL9H7	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 12:55:07.371	2026-06-02 08:25:00.21	2026-06-02 08:25:00.033	123 Test Street, P. B?n Ngh�	Selftest Co.	selftest@example.com	\N	\N	0123456789	t	0	\N
67c580fc-477a-4f1d-aedc-64f40fe57801	BAN-2026-63JSKX	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-05-28 12:55:47.123	2026-06-02 08:25:00.215	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
576af804-e9d9-4a8e-96ae-b38b32ab78f2	BAN-2026-H9ZUP2	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 12:55:47.93	2026-06-02 08:25:00.219	2026-06-02 08:25:00.033	123 Test Street, P. B?n Ngh�	Selftest Co.	selftest@example.com	\N	\N	0123456789	t	0	\N
8945b8b2-4342-42f7-b118-0f86ab8be729	BAN-2026-EUBSSR	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	370000.00	0.00	0	18500.00	\N	0.00	351500.00	\N	\N	2026-05-28 12:56:11.038	2026-06-02 08:25:00.226	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
4477228e-355c-44c3-aa66-006060651356	BAN-2026-TZJ6S4	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 13:42:40.802	2026-06-02 08:25:00.231	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
d1711b85-ffa7-471c-82fa-a2fc8e7d8257	BAN-2026-KMKWT3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-05-28 13:45:05.536	2026-06-02 08:25:00.236	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
1fac125a-c877-4b7c-9df5-c38a5baf89d7	BAN-2026-LEPKF5	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 13:45:06.445	2026-06-02 08:25:00.242	2026-06-02 08:25:00.033	123 Test Street, P. B?n Ngh�	Selftest Co.	selftest@example.com	\N	\N	0123456789	t	0	\N
4ce0cf06-7d6f-4da4-b7b3-f50a995f0e81	BAN-2026-BM5XJL	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 13:45:13.734	2026-06-02 08:25:00.247	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
d54352b3-9021-484c-922a-8e60b62e1717	BAN-2026-CMM66V	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-28 13:45:14.025	2026-06-02 08:25:00.25	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
b2c8b6ee-c6b4-48cd-872d-44c0ee099b2a	BAN-2026-TMSNB4	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-05-28 13:45:46.219	2026-06-02 08:25:00.253	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
6839cfd4-2d2b-4d11-81e9-dff17295ec0c	BAN-2026-P72KD7	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 13:45:54.016	2026-06-02 08:25:00.261	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
1b4901e5-9a3d-4c2c-a66a-19395b5f3eb7	BAN-2026-ZS9HGU	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-28 13:45:54.364	2026-06-02 08:25:00.267	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
1613cc7c-ebbb-4ce0-8d04-b487547caef2	BAN-2026-LELX2Y	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-05-28 13:51:09.78	2026-06-02 08:25:00.271	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
d09490bc-4a8a-4e90-bca2-2993b580cd02	BAN-2026-DM6RH3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-05-28 13:51:15.909	2026-06-02 08:25:00.274	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
99e18f60-be97-4690-b088-46e2d4df8f46	BAN-2026-E58N9M	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 13:51:17.029	2026-06-02 08:25:00.277	2026-06-02 08:25:00.033	123 Test Street, P. B?n Ngh�	Selftest Co.	selftest@example.com	\N	\N	0123456789	t	0	\N
c8de4f77-6501-467f-a7c5-a70cbc551d40	BAN-2026-JEFX87	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 13:51:19.817	2026-06-02 08:25:00.281	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
2c8c866b-ba60-4941-985f-25d5fc8e4080	BAN-2026-JCT4GS	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-28 13:51:20.249	2026-06-02 08:25:00.285	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
2b6d0ea0-e8a9-45a7-815b-19d89c8ecacd	BAN-2026-JRER9M	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 13:51:25.892	2026-06-02 08:25:00.29	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
54d39164-20eb-4ee8-bfed-9308c4ac5c6d	BAN-2026-86DN8J	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-28 13:51:26.166	2026-06-02 08:25:00.294	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
1f62576c-5b36-433b-816a-54ed7730a30d	BAN-2026-Y6MP5F	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-05-28 14:56:52.79	2026-06-02 08:25:00.163	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
e03a6eae-b28f-40b4-a2e6-ea43077690e4	BAN-2026-RCW6CC	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 13:51:10.718	2026-06-02 08:25:00.185	2026-06-02 08:25:00.033	123 Test Street, P. B?n Ngh�	Selftest Co.	selftest@example.com	\N	\N	0123456789	t	0	\N
9b591661-d213-463a-98d0-d01960d09ba8	BAN-2026-LKNXWS	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 13:45:47.087	2026-06-02 08:25:00.257	2026-06-02 08:25:00.033	123 Test Street, P. B?n Ngh�	Selftest Co.	selftest@example.com	\N	\N	0123456789	t	0	\N
f0c33315-a5c8-4b7c-a086-c9e828ceaa19	BAN-2026-45BT3D	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	COMPLETED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-28 18:31:25.714	2026-05-28 18:31:26.696	\N	\N	\N	\N	\N	\N	\N	f	0	\N
0d216cb1-a7fe-43ed-b2c1-a03a6d465eb5	BAN-2026-TKJ5JB	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 14:56:53.812	2026-06-02 08:25:00.297	2026-06-02 08:25:00.033	123 Test Street, P. B?n Ngh�	Selftest Co.	selftest@example.com	\N	\N	0123456789	t	0	\N
f1c3e99c-31d6-4973-be27-21ef727fc522	BAN-2026-6Q2694	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-28 14:57:01.145	2026-06-02 08:25:00.301	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
50f3345d-7363-4dd7-98e3-1544baa8b598	BAN-2026-AH4GMW	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-29 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-28 14:57:01.452	2026-06-02 08:25:00.305	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
e700e920-338a-4b4c-be66-35653f8d8302	BAN-2026-SGESA3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-30 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-29 08:02:41.811	2026-06-02 08:25:00.309	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
94d6b88e-0960-442f-b479-fd1737296478	BAN-2026-4E8HSA	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-30 11:00:00	\N	COMPLETED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-29 08:01:20.269	2026-05-29 08:01:21.396	\N	\N	\N	\N	\N	\N	\N	f	0	\N
e387ebf2-adc9-4618-91d8-5daaab86e242	BAN-2026-254Z3B	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-30 11:00:00	\N	PENDING	\N	VND	185000.00	0.00	0	9250.00	\N	0.00	175750.00	\N	\N	2026-05-29 06:54:13.889	2026-06-02 08:25:00.312	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
850899fc-8c0d-42ea-bb52-1e805cf6fb1b	BAN-2026-23RN2N	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-30 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-05-29 08:01:17.382	2026-06-02 08:25:00.315	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
caf835e3-6fff-4edd-96d7-f90025c415b0	BAN-2026-WA6DH6	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-30 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-29 08:01:17.637	2026-06-02 08:25:00.318	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
be91f242-979e-4a53-b593-8d7f20bd243c	BAN-2026-2Q6DTB	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-30 11:00:00	\N	PENDING	\N	VND	185000.00	0.00	0	9250.00	\N	0.00	175750.00	\N	\N	2026-05-29 08:01:17.925	2026-06-02 08:25:00.32	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c	BAN-2026-V8F3Y9	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-30 11:00:00	243646d1-3453-485c-a6f7-230b38b3e11d	COMPLETED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-29 08:01:21.704	2026-05-29 08:01:22.759	\N	\N	\N	\N	\N	\N	\N	f	0	\N
08c983fd-7a1d-4a55-9f10-ca8cb03d231f	BAN-2026-RGDBY4	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-30 11:00:00	\N	PENDING	\N	VND	838000.00	0.00	0	41900.00	\N	0.00	796100.00	\N	\N	2026-05-29 08:01:18.44	2026-06-02 08:25:00.324	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
59137e9e-e71c-4fe7-80e1-2c071b3ac15e	BAN-2026-TEE93R	61f1af85-9347-49d4-86a3-cb858d5a0b69	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-30 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	0.00	\N	0.00	60000.00	\N	\N	2026-05-29 08:01:19.415	2026-06-02 08:25:00.327	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
fb138522-366c-42f5-a37b-6468cfc2b21a	BAN-2026-TLTRK8	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-05-30 11:00:00	5ef039fd-3c7b-44ed-9bcd-ba7239381791	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-29 08:01:19.645	2026-06-02 08:25:00.33	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
4b2619c3-53b2-4070-9d2d-40493747d077	BAN-2026-YM3G85	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-30 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-29 08:01:28.396	2026-06-02 08:25:00.336	2026-06-02 08:25:00.033	\N	\N	\N	\N	\N	\N	f	0	\N
97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2	BAN-2026-LA522K	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	PICKUP	2026-05-30 11:00:00	\N	COMPLETED	READY_DISPATCH	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-05-29 08:01:23.002	2026-05-29 08:01:24.912	\N	\N	\N	\N	\N	\N	\N	f	0	\N
3dfa2152-e081-405f-af1c-01cf28f36833	BAN-2026-X9RCYA	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	DELIVERY	2026-05-30 11:00:00	855e28e6-37ba-452c-85d9-d82c2479d846	COMPLETED	READY_DISPATCH	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-29 08:01:25.209	2026-05-29 08:01:26.464	\N	\N	\N	\N	\N	\N	\N	f	0	\N
79696db8-7e3d-4408-89aa-d5010de88388	BAN-2026-93KNFS	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-03 11:00:00	\N	COMPLETED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-02 08:57:35.289	2026-06-02 08:57:36.724	\N	\N	\N	\N	\N	\N	\N	f	0	\N
914b19c3-d8ad-46fe-a486-7ca8365ec2b7	BAN-2026-XF973T	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-05-30 11:00:00	\N	ACCEPTED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-29 08:01:27.495	2026-05-29 08:01:28.036	\N	\N	\N	\N	\N	\N	\N	f	0	\N
333f3385-3ef1-468a-b268-0d58e4b8d4d5	BAN-2026-BCGB9X	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	PICKUP	2026-05-30 11:00:00	\N	READY_FOR_PICKUP	READY_DISPATCH	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-05-29 08:01:26.761	2026-06-02 11:06:29.732	\N	\N	\N	\N	\N	\N	\N	f	0	\N
32dcda4c-0995-4645-a367-a97d7d9a9be3	BAN-2026-TFJ388	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-03 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-06-02 08:57:31.079	2026-06-04 06:50:00.08	2026-06-04 06:50:00.018	\N	\N	\N	\N	\N	\N	f	0	\N
cfd9e126-956f-4032-847b-8593ece91985	BAN-2026-74CEF7	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-03 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-06-02 08:57:31.547	2026-06-04 06:50:00.093	2026-06-04 06:50:00.018	\N	\N	\N	\N	\N	\N	f	0	\N
5cc96b01-2502-445c-afd4-34c05f6196b6	BAN-2026-8WANCG	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-03 11:00:00	\N	PENDING	\N	VND	185000.00	0.00	0	9250.00	\N	0.00	175750.00	\N	\N	2026-06-02 08:57:31.959	2026-06-04 06:50:00.096	2026-06-04 06:50:00.018	\N	\N	\N	\N	\N	\N	f	0	\N
02ff0412-d0f6-4619-8263-c6c4b4d4b6a1	BAN-2026-VLRVDW	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-03 11:00:00	\N	PENDING	\N	VND	838000.00	0.00	0	41900.00	\N	0.00	796100.00	\N	\N	2026-06-02 08:57:32.663	2026-06-04 06:50:00.101	2026-06-04 06:50:00.018	\N	\N	\N	\N	\N	\N	f	0	\N
ae1b56a6-baef-45fc-bdcc-b66841201677	BAN-2026-E2VGLP	d70495ff-161a-4f2b-a817-540ca2658367	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-03 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	0.00	\N	0.00	60000.00	\N	\N	2026-06-02 08:57:34.184	2026-06-04 06:50:00.104	2026-06-04 06:50:00.018	\N	\N	\N	\N	\N	\N	f	0	\N
2cc97ad0-2af0-4b4b-9bea-94e4383e4628	BAN-2026-ENND3U	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-06-03 11:00:00	406d4e5c-1fc6-4ec5-924f-618b7dc5cf7e	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-02 08:57:34.573	2026-06-04 06:50:00.108	2026-06-04 06:50:00.018	\N	\N	\N	\N	\N	\N	f	0	\N
ef97c0c0-67be-4cce-aa98-efa1aa3a74bc	BAN-2026-6JESW4	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-06-03 11:00:00	3c3a61ce-f95c-442d-a9d1-f13a9ea753a0	COMPLETED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-02 08:57:37.069	2026-06-02 08:57:38.241	\N	\N	\N	\N	\N	\N	\N	f	0	\N
22cb5aaf-7cd9-4483-8232-0209b84636b6	BAN-2026-ZFUU86	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	PICKUP	2026-06-03 11:00:00	\N	COMPLETED	READY_DISPATCH	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-06-02 08:57:38.549	2026-06-02 08:57:40.859	\N	\N	\N	\N	\N	\N	\N	f	0	\N
05c829ec-c0fd-41b1-9c05-102bd43439a6	BAN-2026-84N9Q3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	DELIVERY	2026-06-03 11:00:00	c98b8616-bf01-4cff-991f-3b007760c740	COMPLETED	READY_DISPATCH	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-02 08:57:41.147	2026-06-02 08:57:42.463	\N	\N	\N	\N	\N	\N	\N	f	0	\N
d65f2099-6c4d-456c-8dc2-87d357842f4c	BAN-2026-P3YS8Q	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-03 11:00:00	\N	CANCELLED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-02 08:57:43.589	2026-06-02 08:57:43.871	\N	\N	\N	\N	\N	\N	\N	f	0	\N
a3236cb6-463b-4402-8bc7-fcbd666257d6	BAN-2026-HSUU8W	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-03 11:00:00	\N	CANCELLED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-02 08:57:44.306	2026-06-02 08:57:44.783	\N	\N	\N	\N	\N	\N	\N	f	0	\N
f5158425-e1b1-48a9-bca8-8e4bf4fa337d	BAN-2026-7CTCY4	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-03 11:00:00	\N	ACCEPTED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-02 10:34:27.088	2026-06-02 10:34:27.356	\N	\N	\N	\N	\N	\N	\N	f	0	\N
031479dc-1160-471b-a16f-cce9ff1625f6	BAN-2026-G3JFDG	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	PICKUP	2026-06-03 11:00:00	\N	READY_FOR_PICKUP	READY_DISPATCH	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-02 08:57:42.826	2026-06-02 11:06:32.33	\N	\N	\N	\N	\N	\N	\N	f	0	\N
a70eece6-5748-4365-a6ab-990aaf2249cf	BAN-2026-DKH3QH	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	PICKUP	2026-06-03 11:00:00	\N	READY_FOR_PICKUP	READY_DISPATCH	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-02 10:54:09.796	2026-06-02 11:06:33.286	\N	\N	\N	\N	\N	\N	\N	f	0	\N
67f14c8a-c137-4a45-974c-45ab1df77460	BAN-2026-P37JDU	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-03 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-06-02 11:09:20.401	2026-06-04 06:50:00.112	2026-06-04 06:50:00.018	\N	\N	\N	\N	\N	\N	f	0	\N
671dcde8-bf46-4361-9302-38ba388c2577	BAN-2026-LQPC7H	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-06-03 11:00:00	f629518a-8d11-4a09-ac9e-be2111c6731a	PENDING	\N	VND	778000.00	30000.00	0	38900.00	\N	0.00	769100.00	\N	\N	2026-06-02 11:09:20.588	2026-06-04 06:50:00.116	2026-06-04 06:50:00.018	\N	\N	\N	\N	\N	\N	f	0	\N
175701bc-0450-4429-96d5-735e9aafcb82	BAN-2026-ME4WSK	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-05 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	0.00	\N	\N	2026-06-04 14:11:21.195	2026-06-04 14:11:21.195	\N	\N	\N	\N	\N	\N	\N	f	57000	BNGC-GC5P-5BHD
2e5538cf-93fc-4590-9858-68d6fe7e5fd6	BAN-2026-SVDW4B	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-05 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	0.00	\N	\N	2026-06-04 14:24:51.109	2026-06-04 14:24:51.109	\N	\N	\N	\N	\N	\N	\N	f	57000	BNGC-8HCS-YUC5
94e2d801-4952-476a-83d2-b0ff9d87de66	BAN-2026-32U5RS	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-05 11:00:00	\N	PENDING	\N	VND	120000.00	0.00	0	6000.00	\N	0.00	114000.00	\N	\N	2026-06-04 14:25:15.773	2026-06-04 14:25:15.773	\N	\N	\N	\N	\N	\N	\N	f	0	\N
4f927fab-084c-4a89-99d0-079e924b8819	BAN-2026-TW7F9N	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-05 11:00:00	\N	PENDING	\N	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-06-04 14:25:16.087	2026-06-04 14:25:16.087	\N	\N	\N	\N	\N	\N	\N	f	0	\N
d411c7d5-fcac-48eb-9f26-3df9366f17be	BAN-2026-PXSU99	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-05 11:00:00	\N	PENDING	\N	VND	185000.00	0.00	0	9250.00	\N	0.00	175750.00	\N	\N	2026-06-04 14:25:16.417	2026-06-04 14:25:16.417	\N	\N	\N	\N	\N	\N	\N	f	0	\N
21417b81-1fe7-461d-b3ac-6bd595328a35	BAN-2026-QGC8DL	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-05 11:00:00	\N	PENDING	\N	VND	838000.00	0.00	0	41900.00	\N	0.00	796100.00	\N	\N	2026-06-04 14:25:17.001	2026-06-04 14:25:17.001	\N	\N	\N	\N	\N	\N	\N	f	0	\N
d11bfa82-317d-4bf1-92ac-ae822d083dd8	BAN-2026-89F2GQ	0502db59-3b85-40bc-9325-3556c61967c1	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-05 11:00:00	\N	PENDING	\N	VND	60000.00	0.00	0	0.00	\N	0.00	60000.00	\N	\N	2026-06-04 14:25:17.799	2026-06-04 14:25:17.799	\N	\N	\N	\N	\N	\N	\N	f	0	\N
6962c74f-4108-46dc-9f03-1d6db00a6751	BAN-2026-A6F9WW	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-06-05 11:00:00	2ff58fac-4430-4b50-bd37-c053daf5b09c	PENDING	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-04 14:25:18.134	2026-06-04 14:25:18.134	\N	\N	\N	\N	\N	\N	\N	f	0	\N
5066a015-de2b-4f75-acac-357c4ade16cd	BAN-2026-F48DNC	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-05 11:00:00	\N	COMPLETED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-04 14:25:18.72	2026-06-04 14:25:19.833	\N	\N	\N	\N	\N	\N	\N	f	0	\N
c4b3e273-2560-4dab-ab8a-64c3afb68727	BAN-2026-PCNBQ9	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	DELIVERY	2026-06-05 11:00:00	15899ed7-96fa-41b8-babe-e32ff60494c3	COMPLETED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-04 14:25:20.105	2026-06-04 14:25:21.119	\N	\N	\N	\N	\N	\N	\N	f	0	\N
6a92f954-1fb8-4cbd-a9aa-7423dde45627	BAN-2026-NDMF2R	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	PICKUP	2026-06-05 11:00:00	\N	COMPLETED	READY_DISPATCH	VND	778000.00	0.00	0	38900.00	\N	0.00	739100.00	\N	\N	2026-06-04 14:25:21.329	2026-06-04 14:25:23.243	\N	\N	\N	\N	\N	\N	\N	f	0	\N
4831b162-0d0d-40df-a1b9-5360d034f731	BAN-2026-PNM4ZM	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	DELIVERY	2026-06-05 11:00:00	c746e37c-9b5c-4ab2-9369-946968852a8a	COMPLETED	READY_DISPATCH	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-04 14:25:23.506	2026-06-04 14:25:24.676	\N	\N	\N	\N	\N	\N	\N	f	0	\N
932e0a80-ad20-4c57-87e1-45770d409aa7	BAN-2026-W6MBWV	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	kitchen-main	PICKUP	2026-06-05 11:00:00	\N	SENT_TO_KITCHEN	PENDING_ACK	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-04 14:25:24.895	2026-06-04 14:25:25.282	\N	\N	\N	\N	\N	\N	\N	f	0	\N
31e11ed9-a86d-4403-97f4-0ad0fda04556	BAN-2026-D8KH6E	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-05 11:00:00	\N	CANCELLED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-04 14:25:25.528	2026-06-04 14:25:25.805	\N	\N	\N	\N	\N	\N	\N	f	0	\N
7b4a9ff3-9a49-4b5d-84ac-8ce47f65a291	BAN-2026-4WDK3E	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-05 11:00:00	\N	CANCELLED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-04 14:25:26.189	2026-06-04 14:25:26.611	\N	\N	\N	\N	\N	\N	\N	f	0	\N
cf3c0c8e-40aa-4025-9580-b4c941f82ece	BAN-2026-ZP6PZT	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa237695-edd5-482e-aca5-54401f046b28	\N	PICKUP	2026-06-05 11:00:00	\N	ACCEPTED	\N	VND	60000.00	0.00	0	3000.00	\N	0.00	57000.00	\N	\N	2026-06-04 14:25:41.745	2026-06-04 14:25:42.03	\N	\N	\N	\N	\N	\N	\N	f	0	\N
\.


ALTER TABLE public."Order" ENABLE TRIGGER ALL;

--
-- Data for Name: CouponRedemption; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."CouponRedemption" DISABLE TRIGGER ALL;

COPY public."CouponRedemption" (id, "couponId", "userId", "orderId", "createdAt") FROM stdin;
\.


ALTER TABLE public."CouponRedemption" ENABLE TRIGGER ALL;

--
-- Data for Name: DeliveryConfig; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."DeliveryConfig" DISABLE TRIGGER ALL;

COPY public."DeliveryConfig" (id, "standardFeeSameWardVnd", "standardFeeOtherWardVnd", "birthdayCakeFeeSameWardVnd", "birthdayCakeFeeOtherWardVnd", "birthdayCakeCollectionSlug", "thresholdKm", "updatedAt") FROM stdin;
default	0	30000	30000	70000	home-birthday-cakes	3	2026-05-20 11:20:24.649
\.


ALTER TABLE public."DeliveryConfig" ENABLE TRIGGER ALL;

--
-- Data for Name: DeviceToken; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."DeviceToken" DISABLE TRIGGER ALL;

COPY public."DeviceToken" (id, "userId", platform, token, "lastSeen", "createdAt") FROM stdin;
\.


ALTER TABLE public."DeviceToken" ENABLE TRIGGER ALL;

--
-- Data for Name: DisplayConfig; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."DisplayConfig" DISABLE TRIGGER ALL;

COPY public."DisplayConfig" (id, "showStockToCustomers", "updatedAt", "contactEmail", "contactMessengerId", "contactPhone", "contactZaloOaId") FROM stdin;
default	f	2026-06-04 14:40:22.361	\N	\N	\N	\N
\.


ALTER TABLE public."DisplayConfig" ENABLE TRIGGER ALL;

--
-- Data for Name: GiftCard; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."GiftCard" DISABLE TRIGGER ALL;

COPY public."GiftCard" (id, code, "initialVnd", "balanceVnd", "expiresAt", "isActive", note, "issuedById", "createdAt", "updatedAt") FROM stdin;
1484dacc-105d-47be-825e-d44353523cc2	BNGC-GC5P-5BHD	500000	443000	\N	t	test	aedd04e8-4140-437f-b66b-0f133c42b11f	2026-06-04 14:11:20.296	2026-06-04 14:11:21.189
ec83d729-574a-4d8d-8689-70ed770c9942	BNGC-8HCS-YUC5	100000	43000	\N	f	selftest	aedd04e8-4140-437f-b66b-0f133c42b11f	2026-06-04 14:24:50.26	2026-06-04 14:24:51.715
\.


ALTER TABLE public."GiftCard" ENABLE TRIGGER ALL;

--
-- Data for Name: LoyaltyEvent; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."LoyaltyEvent" DISABLE TRIGGER ALL;

COPY public."LoyaltyEvent" (id, "userId", "orderId", type, delta, "balanceAfter", reason, "expiresAt", "createdAt") FROM stdin;
43094db4-c76a-4150-89fd-8de11136e883	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	0cf1fecb-9856-447c-8a88-3bd8adff8bc9	EARN	24	1524	Earned on order BAN-2026-FXCU2J	\N	2026-05-13 08:16:12.548
a36c0f9f-9bd0-4c02-803a-3c3614dac2fb	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	322fdd05-ee34-4cbe-8f99-e5eb37ed5314	EARN	24	1548	Earned on order BAN-2026-AYBNAF	\N	2026-05-13 09:35:54.68
5abe11af-4fb7-403f-b12a-b2e464453015	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	2d79c95b-ce16-459d-91cf-53d1f39edc4a	EARN	24	1572	Earned on order BAN-2026-RKHUZC	\N	2026-05-13 10:43:06.619
556e6e51-c54e-49f5-9126-3c21b6f9839d	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	060470be-e651-4d99-b519-9ea5491effd9	EARN	24	1596	Earned on order BAN-2026-HK7TLK	\N	2026-05-14 05:09:19.755
78cd8fa9-2120-4767-87cb-0e914907f563	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	c47b501f-763d-4a2d-bf4b-2377d8c39b6f	EARN	42	1638	Earned on order BAN-2026-BLMXZS	\N	2026-05-15 10:52:04.255
efdcedf6-ae90-4145-8ad8-5b827c9ed452	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	54081945-a072-4dc5-924c-60aa005a4344	EARN	56	1694	Earned on order BAN-2026-LLLP8B	\N	2026-05-15 10:56:27.406
900444e6-3ceb-484b-86ef-e04fccd6ec15	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	a2476e33-44d3-4c2b-ad4d-798099f6522c	EARN	24	1718	Earned on order BAN-2026-CCNMLX	\N	2026-05-15 11:01:31.196
16150d91-375e-4762-bb77-e26bddbd6f3e	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	\N	ADJUSTMENT	50	50	Birthday gift	\N	2026-05-17 08:58:25.491
229b5909-3c03-4e30-98d7-cc49162d8ae9	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	f0c33315-a5c8-4b7c-a086-c9e828ceaa19	EARN	1	1719	Earned on order BAN-2026-45BT3D	\N	2026-05-28 18:31:26.741
0112a2d8-3022-472b-a079-6ade4cf8bc04	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	94d6b88e-0960-442f-b479-fd1737296478	EARN	1	1720	Earned on order BAN-2026-4E8HSA	\N	2026-05-29 08:01:21.445
bf94fddf-f4f2-4311-a4c6-6c6358442b6e	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c	EARN	1	1721	Earned on order BAN-2026-V8F3Y9	\N	2026-05-29 08:01:22.808
738034ad-e7af-4ae4-a347-e00bc4b334be	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2	EARN	15	1736	Earned on order BAN-2026-LA522K	\N	2026-05-29 08:01:24.963
cc7813f2-76a2-41e3-8f5b-17213cd54b6a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	3dfa2152-e081-405f-af1c-01cf28f36833	EARN	1	1737	Earned on order BAN-2026-X9RCYA	\N	2026-05-29 08:01:26.497
5a607dd7-9979-4098-b1ba-3dd33761d00d	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	79696db8-7e3d-4408-89aa-d5010de88388	EARN	1	1738	Earned on order BAN-2026-93KNFS	\N	2026-06-02 08:57:36.781
3e77e2ba-d9dd-4dee-bb72-d9040a7dd9ff	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	ef97c0c0-67be-4cce-aa98-efa1aa3a74bc	EARN	1	1739	Earned on order BAN-2026-6JESW4	\N	2026-06-02 08:57:38.294
4b9af006-8da2-4ad6-808a-14e742d7ac3b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	22cb5aaf-7cd9-4483-8232-0209b84636b6	EARN	15	1754	Earned on order BAN-2026-ZFUU86	\N	2026-06-02 08:57:40.9
044034be-7256-4235-a6e3-d5f59fd6626c	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	05c829ec-c0fd-41b1-9c05-102bd43439a6	EARN	1	1755	Earned on order BAN-2026-84N9Q3	\N	2026-06-02 08:57:42.57
daf8e4a7-edd9-4968-9430-255ff5cb0e15	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	5066a015-de2b-4f75-acac-357c4ade16cd	EARN	1	1756	Earned on order BAN-2026-F48DNC	\N	2026-06-04 14:25:19.869
b65f3059-2ae4-4407-b9dc-8fe070309746	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	c4b3e273-2560-4dab-ab8a-64c3afb68727	EARN	1	1757	Earned on order BAN-2026-PCNBQ9	\N	2026-06-04 14:25:21.16
51d9deab-2b9d-4ea0-94e4-8fe50ce197e0	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	6a92f954-1fb8-4cbd-a9aa-7423dde45627	EARN	15	1772	Earned on order BAN-2026-NDMF2R	\N	2026-06-04 14:25:23.277
5ac65fc6-e947-4847-8f11-1b8acbbfaaca	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	4831b162-0d0d-40df-a1b9-5360d034f731	EARN	1	1773	Earned on order BAN-2026-PNM4ZM	\N	2026-06-04 14:25:24.71
\.


ALTER TABLE public."LoyaltyEvent" ENABLE TRIGGER ALL;

--
-- Data for Name: MarketingConfig; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."MarketingConfig" DISABLE TRIGGER ALL;

COPY public."MarketingConfig" (id, "referralEnabled", "referralConfig", "giftCardEnabled", "giftCardConfig", "subscriptionEnabled", "subscriptionConfig", "cateringEnabled", "cateringConfig", "rewardsEnabled", "rewardsConfig", "updatedAt") FROM stdin;
default	f	\N	f	\N	f	\N	f	{"minGuests": 30}	f	\N	2026-06-04 14:24:49.941
\.


ALTER TABLE public."MarketingConfig" ENABLE TRIGGER ALL;

--
-- Data for Name: NewsletterSubscriber; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."NewsletterSubscriber" DISABLE TRIGGER ALL;

COPY public."NewsletterSubscriber" (id, email, "fullName", source, "unsubscribeToken", "subscribedAt", "confirmedAt", "unsubscribedAt") FROM stdin;
58cfce31-c6f3-4ffd-8a33-f6b24b15cfaa	test-newsletter@example.com	Selftest	footer	45b03459-fe73-438c-ad85-4a17311bc920	2026-05-28 13:26:03.673	2026-05-28 13:26:05.426	\N
b3132cad-b31e-4133-9cef-2cdbf8713953	selftest+1779975911@example.com	Selftest	selftest	77602254-c51a-4cff-b42c-30c948c2693f	2026-05-28 13:45:11.422	2026-05-28 13:45:12.73	2026-05-28 13:45:13.023
6cfb94d8-4e7c-424d-b263-11537fb63aa0	selftest+1779975951@example.com	Selftest	selftest	eb1fd144-6550-4881-8350-6050ba759299	2026-05-28 13:45:51.533	2026-05-28 13:45:52.765	2026-05-28 13:45:53.064
56eebe7b-b26e-4084-8679-ab16637c8575	selftest+1779976276@example.com	Selftest	selftest	479683fb-0d68-4df9-8f08-1bac6b156e18	2026-05-28 13:51:16.492	2026-05-28 13:51:18.512	2026-05-28 13:51:18.905
165fdb52-af4a-454b-bd5e-be1f65f5c0f1	selftest+1779976283@example.com	Selftest	selftest	c1f27e67-0c2c-490a-ae35-5cf2a440aea8	2026-05-28 13:51:23.255	2026-05-28 13:51:24.852	2026-05-28 13:51:25.152
94d60880-a3ef-4835-9b7d-75882043fe15	selftest+1779980218@example.com	Selftest	selftest	b320b80a-da23-4e29-975b-82232cdc887b	2026-05-28 14:56:58.54	2026-05-28 14:56:59.957	2026-05-28 14:57:00.322
\.


ALTER TABLE public."NewsletterSubscriber" ENABLE TRIGGER ALL;

--
-- Data for Name: Notification; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Notification" DISABLE TRIGGER ALL;

COPY public."Notification" (id, "userId", type, title, body, data, "readAt", "createdAt") FROM stdin;
d4dec47d-8373-4e2d-b5fa-b594ab8e1d2b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order accepted	Your order BAN-2026-AYBNAF has been accepted.	{"code": "BAN-2026-AYBNAF", "status": "ACCEPTED", "orderId": "322fdd05-ee34-4cbe-8f99-e5eb37ed5314"}	2026-05-13 08:14:31.15	2026-05-13 08:13:38.96
e2f66af9-5c99-480c-83c1-9d1e7cb5fbd2	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Being prepared	We're preparing your order BAN-2026-AYBNAF.	{"code": "BAN-2026-AYBNAF", "status": "IN_PREPARATION", "orderId": "322fdd05-ee34-4cbe-8f99-e5eb37ed5314"}	2026-05-13 08:14:31.15	2026-05-13 08:13:44.231
d5504419-4d73-480f-9b67-cbc4c4d4cef6	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Ready for pickup	Order BAN-2026-AYBNAF is ready for pickup!	{"code": "BAN-2026-AYBNAF", "status": "READY_FOR_PICKUP", "orderId": "322fdd05-ee34-4cbe-8f99-e5eb37ed5314"}	2026-05-13 08:14:31.15	2026-05-13 08:13:48.029
8dacba4d-3ec3-4f4a-b1c5-0eec19c0383f	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Sent to central kitchen	Order BAN-2026-FXCU2J is being crafted at our central kitchen.	{"code": "BAN-2026-FXCU2J", "status": "SENT_TO_KITCHEN", "orderId": "0cf1fecb-9856-447c-8a88-3bd8adff8bc9"}	2026-05-13 08:15:13.081	2026-05-13 08:15:04.14
961cc1d3-4ebe-4d9c-9746-bac344c158c7	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Ready to dispatch	Order BAN-2026-FXCU2J is now ready to dispatch.	{"code": "BAN-2026-FXCU2J", "orderId": "0cf1fecb-9856-447c-8a88-3bd8adff8bc9", "kitchenStatus": "READY_DISPATCH"}	2026-05-13 08:20:28.104	2026-05-13 08:15:32.4
4a21461a-1c09-4b28-a1e0-d7e45e279036	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Kitchen preparing	Order BAN-2026-FXCU2J is now kitchen preparing.	{"code": "BAN-2026-FXCU2J", "orderId": "0cf1fecb-9856-447c-8a88-3bd8adff8bc9", "kitchenStatus": "PREPARING"}	2026-05-13 08:20:43.578	2026-05-13 08:15:29.962
b83884cc-182b-4533-a38a-98fc86a2da9c	3293c2bf-4ceb-4e45-8597-61bad26a4bad	order.status_changed	Order accepted	Your order BAN-2026-PSNK4N has been accepted.	{"code": "BAN-2026-PSNK4N", "status": "ACCEPTED", "orderId": "81d4c479-c7be-46fd-8181-6dc4616541bb"}	\N	2026-05-13 09:36:01.989
208afefa-31d3-45dc-810f-97438e44abd4	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Ready to dispatch	Order BAN-2026-RKHUZC is now ready to dispatch.	{"code": "BAN-2026-RKHUZC", "orderId": "2d79c95b-ce16-459d-91cf-53d1f39edc4a", "kitchenStatus": "READY_DISPATCH"}	2026-05-13 10:38:33.474	2026-05-13 09:59:23.178
dc8cbba0-9ac5-4048-8a55-aa6764fffe29	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	order.status_changed	Order accepted	Your order BAN-2026-UHW22V has been accepted.	{"code": "BAN-2026-UHW22V", "status": "ACCEPTED", "orderId": "36cb2b2b-f0e8-44b5-bc59-23931e320913"}	\N	2026-05-14 05:06:02.474
a3e23689-51c3-4a54-8a58-ac1f8789da13	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order accepted	Your order BAN-2026-FXCU2J has been accepted.	{"code": "BAN-2026-FXCU2J", "status": "ACCEPTED", "orderId": "0cf1fecb-9856-447c-8a88-3bd8adff8bc9"}	2026-05-14 07:31:14.439	2026-05-13 08:14:54.111
6f32eb5d-9c6e-41db-a849-280f4953c421	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order completed	Thanks for your order BAN-2026-FXCU2J. Enjoy!	{"code": "BAN-2026-FXCU2J", "status": "COMPLETED", "orderId": "0cf1fecb-9856-447c-8a88-3bd8adff8bc9"}	2026-05-14 07:31:14.439	2026-05-13 08:16:12.564
f1032675-9586-4a16-b7e8-6b6a61f4d13a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order completed	Thanks for your order BAN-2026-AYBNAF. Enjoy!	{"code": "BAN-2026-AYBNAF", "status": "COMPLETED", "orderId": "322fdd05-ee34-4cbe-8f99-e5eb37ed5314"}	2026-05-14 07:31:14.439	2026-05-13 09:35:54.691
22cee59d-498b-4d86-8c79-0ee4e1ca0142	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order accepted	Your order BAN-2026-RKHUZC has been accepted.	{"code": "BAN-2026-RKHUZC", "status": "ACCEPTED", "orderId": "2d79c95b-ce16-459d-91cf-53d1f39edc4a"}	2026-05-14 07:31:14.439	2026-05-13 09:58:14.182
b0417061-55aa-4e49-ab60-82765257addf	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Sent to central kitchen	Order BAN-2026-RKHUZC is being crafted at our central kitchen.	{"code": "BAN-2026-RKHUZC", "status": "SENT_TO_KITCHEN", "orderId": "2d79c95b-ce16-459d-91cf-53d1f39edc4a"}	2026-05-14 07:31:14.439	2026-05-13 09:58:15.534
47867542-df4a-4506-9278-4f265a18b536	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Kitchen preparing	Order BAN-2026-RKHUZC is now kitchen preparing.	{"code": "BAN-2026-RKHUZC", "orderId": "2d79c95b-ce16-459d-91cf-53d1f39edc4a", "kitchenStatus": "PREPARING"}	2026-05-14 07:31:14.439	2026-05-13 09:58:48.418
09d0aa4a-19ba-41a1-b03a-dabf65419abf	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order completed	Thanks for your order BAN-2026-RKHUZC. Enjoy!	{"code": "BAN-2026-RKHUZC", "status": "COMPLETED", "orderId": "2d79c95b-ce16-459d-91cf-53d1f39edc4a"}	2026-05-14 07:31:14.439	2026-05-13 10:43:06.629
956a0314-e454-4ab7-8053-d7311b6d45bd	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-ME4WSK	1 món · Lấy tại quầy	{"code": "BAN-2026-ME4WSK"}	\N	2026-06-04 14:11:21.299
08ae60d3-0e6c-4c7f-8c21-83db75c80e01	3293c2bf-4ceb-4e45-8597-61bad26a4bad	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
6fe5644c-2fa2-4113-80af-80adbcba74ec	79e5bda1-a575-4b5f-9eca-d6fe2d91ea1f	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
33456b2e-c292-46e5-b35f-6caece7c6be8	0886d71a-9289-4444-a914-a6cf76832b64	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
3c360ee5-3916-4c1e-a1ed-98957d170618	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
d60c7eea-aed9-46cd-976d-bc89c4066956	1b9a0dcc-45a6-414c-b6ac-2140ee99d84d	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
b3231bfc-789f-496b-9093-3ff5e3212317	63a01e12-3073-48e7-a620-900c0fcb2e28	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
131f9daf-e0a2-477e-93ad-23a29c785d76	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
224c80e0-31e5-494a-b3c4-3b6f3074c75a	9aa53cfd-c56a-4096-803a-f4b0d75bf805	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
c4d2025c-4456-4605-94ce-a2be39e9bc3f	783498ab-9459-4f48-869e-300495ef7bf9	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
96f61b83-bc18-4d46-bd14-929fd717d18e	61f1af85-9347-49d4-86a3-cb858d5a0b69	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
3adc8270-dd03-4eb5-9e72-8227b372f140	10291bfb-c4ed-463e-a626-09bed34891dd	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
85d416f5-d535-4c82-9ff2-4efac3b32293	5d28a394-1d64-4ae7-9b9b-3b6313b1686d	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
15a29bff-1a57-426f-9cbb-ba72295e7726	f10163ab-fd73-4441-af99-8be5d9f4cc34	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
2f2fdf95-d37d-487c-8e35-f7f322ba92f0	d70495ff-161a-4f2b-a817-540ca2658367	campaign	Selftest	thong bao kiem tra	\N	\N	2026-06-04 14:24:49.091
f77c9b29-e9f2-4bfd-b303-7a17454a613e	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-SVDW4B	1 món · Lấy tại quầy	{"code": "BAN-2026-SVDW4B"}	\N	2026-06-04 14:24:51.183
04cbb7be-bb82-4b74-850e-e85f114c6786	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-32U5RS	1 món · Lấy tại quầy	{"code": "BAN-2026-32U5RS"}	\N	2026-06-04 14:25:15.834
d1bf7e1b-55a0-4da2-b4a6-db1dec429899	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-32U5RS	1 món · Lấy tại quầy	{"code": "BAN-2026-32U5RS"}	\N	2026-06-04 14:25:15.841
24c5f457-acb7-450f-889a-836d59d232ce	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order accepted	Your order BAN-2026-HK7TLK has been accepted.	{"code": "BAN-2026-HK7TLK", "status": "ACCEPTED", "orderId": "060470be-e651-4d99-b519-9ea5491effd9"}	2026-05-14 07:31:14.439	2026-05-14 05:08:23.028
1bec5b2a-3803-470f-8346-9e738b3d1433	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Sent to central kitchen	Order BAN-2026-HK7TLK is being crafted at our central kitchen.	{"code": "BAN-2026-HK7TLK", "status": "SENT_TO_KITCHEN", "orderId": "060470be-e651-4d99-b519-9ea5491effd9"}	2026-05-14 07:31:14.439	2026-05-14 05:08:24.417
599beaf5-c66f-420d-b23e-5f2c664525d3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Kitchen preparing	Order BAN-2026-HK7TLK is now kitchen preparing.	{"code": "BAN-2026-HK7TLK", "orderId": "060470be-e651-4d99-b519-9ea5491effd9", "kitchenStatus": "PREPARING"}	2026-05-14 07:31:14.439	2026-05-14 05:08:47.663
7263478d-a304-4fcf-a43a-3cfb62f4b49c	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Ready to dispatch	Order BAN-2026-HK7TLK is now ready to dispatch.	{"code": "BAN-2026-HK7TLK", "orderId": "060470be-e651-4d99-b519-9ea5491effd9", "kitchenStatus": "READY_DISPATCH"}	2026-05-14 07:31:14.439	2026-05-14 05:08:49.258
51d849a4-9c3c-460d-8b00-b98949b39a60	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order completed	Thanks for your order BAN-2026-HK7TLK. Enjoy!	{"code": "BAN-2026-HK7TLK", "status": "COMPLETED", "orderId": "060470be-e651-4d99-b519-9ea5491effd9"}	2026-05-14 07:31:14.439	2026-05-14 05:09:19.784
2201ff5a-40fd-4c4f-bc20-d75bc7503b6b	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	merchant.message	C?m on b?n	C?m on d� ?ng h? Banan!	null	\N	2026-05-17 08:58:15.463
416e60f1-96c0-4e08-beed-aa1839bc5dab	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	loyalty.adjustment	You received Micho!	+50 Micho — Birthday gift. New balance: 50.	null	\N	2026-05-17 08:58:25.508
90cedd70-d380-4947-a2ed-1c532626fd7c	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	coupon.gift	A gift for you 🎁	Use code BANAN-3E9CE3E9 for 15% off on your next order. Valid until 16/6/2026.	null	\N	2026-05-17 08:58:25.703
b2b4472c-746f-485c-a7b7-a887442edbd6	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order completed	Thanks for your order BAN-2026-CCNMLX. Enjoy!	{"code": "BAN-2026-CCNMLX", "status": "COMPLETED", "orderId": "a2476e33-44d3-4c2b-ad4d-798099f6522c"}	2026-05-18 11:23:09.806	2026-05-15 11:01:31.208
f89834a3-7c40-48c9-8388-b53aaf5dc96a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order accepted	Your order BAN-2026-BLMXZS has been accepted.	{"code": "BAN-2026-BLMXZS", "status": "ACCEPTED", "orderId": "c47b501f-763d-4a2d-bf4b-2377d8c39b6f"}	2026-05-18 15:02:08.311	2026-05-15 10:51:59.882
42b35abe-f491-4403-a70c-f13592d75494	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Being prepared	We're preparing your order BAN-2026-BLMXZS.	{"code": "BAN-2026-BLMXZS", "status": "IN_PREPARATION", "orderId": "c47b501f-763d-4a2d-bf4b-2377d8c39b6f"}	2026-05-18 15:02:08.311	2026-05-15 10:52:01.496
707c96dd-36d3-441d-a2c5-97ba36dbb1ee	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Ready for pickup	Order BAN-2026-BLMXZS is ready for pickup!	{"code": "BAN-2026-BLMXZS", "status": "READY_FOR_PICKUP", "orderId": "c47b501f-763d-4a2d-bf4b-2377d8c39b6f"}	2026-05-18 15:02:08.311	2026-05-15 10:52:03.313
a60bd817-6591-4c24-bac6-76ed2f5e5ea1	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order completed	Thanks for your order BAN-2026-BLMXZS. Enjoy!	{"code": "BAN-2026-BLMXZS", "status": "COMPLETED", "orderId": "c47b501f-763d-4a2d-bf4b-2377d8c39b6f"}	2026-05-18 15:02:08.311	2026-05-15 10:52:04.267
0c07f96b-7d33-4d8e-a621-9de115ddd33a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order accepted	Your order BAN-2026-LLLP8B has been accepted.	{"code": "BAN-2026-LLLP8B", "status": "ACCEPTED", "orderId": "54081945-a072-4dc5-924c-60aa005a4344"}	2026-05-18 15:02:08.311	2026-05-15 10:56:24.767
7add76ed-13e4-48af-978d-f92846526356	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Being prepared	We're preparing your order BAN-2026-LLLP8B.	{"code": "BAN-2026-LLLP8B", "status": "IN_PREPARATION", "orderId": "54081945-a072-4dc5-924c-60aa005a4344"}	2026-05-18 15:02:08.311	2026-05-15 10:56:26.022
e599db8d-6ade-4cc7-b47f-e034a47b16f3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Ready for pickup	Order BAN-2026-LLLP8B is ready for pickup!	{"code": "BAN-2026-LLLP8B", "status": "READY_FOR_PICKUP", "orderId": "54081945-a072-4dc5-924c-60aa005a4344"}	2026-05-18 15:02:08.311	2026-05-15 10:56:26.68
0facd378-2995-4a91-ae41-d498e8db088d	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order completed	Thanks for your order BAN-2026-LLLP8B. Enjoy!	{"code": "BAN-2026-LLLP8B", "status": "COMPLETED", "orderId": "54081945-a072-4dc5-924c-60aa005a4344"}	2026-05-18 15:02:08.311	2026-05-15 10:56:27.425
1fbbfbf5-c00a-42bc-8c0e-34f85a379374	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Order accepted	Your order BAN-2026-CCNMLX has been accepted.	{"code": "BAN-2026-CCNMLX", "status": "ACCEPTED", "orderId": "a2476e33-44d3-4c2b-ad4d-798099f6522c"}	2026-05-18 15:02:08.311	2026-05-15 11:01:08.663
03eb6be0-2218-40a6-92f5-73bb1ea46f7d	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Being prepared	We're preparing your order BAN-2026-CCNMLX.	{"code": "BAN-2026-CCNMLX", "status": "IN_PREPARATION", "orderId": "a2476e33-44d3-4c2b-ad4d-798099f6522c"}	2026-05-18 15:02:08.311	2026-05-15 11:01:29.871
82ea78fd-00ae-4d16-ac11-d2cde06d1852	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Ready for pickup	Order BAN-2026-CCNMLX is ready for pickup!	{"code": "BAN-2026-CCNMLX", "status": "READY_FOR_PICKUP", "orderId": "a2476e33-44d3-4c2b-ad4d-798099f6522c"}	2026-05-18 15:02:08.311	2026-05-15 11:01:30.537
42be23cc-842b-4759-a4f7-a92cc1df340c	3293c2bf-4ceb-4e45-8597-61bad26a4bad	merchant.broadcast	Khai truong tu?n n�y	�?n c?a h�ng L� Th�nh T�n nh?n qu� nh�!	null	\N	2026-05-20 08:44:58.658
a07e6b24-9817-4ba6-97c3-ef6de1f78b1f	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	merchant.broadcast	Khai truong tu?n n�y	�?n c?a h�ng L� Th�nh T�n nh?n qu� nh�!	null	\N	2026-05-20 08:44:58.691
842eb2ae-c3f4-4642-adf5-6cf43bab2c1b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	merchant.broadcast	Khai truong tu?n n�y	�?n c?a h�ng L� Th�nh T�n nh?n qu� nh�!	null	2026-05-20 10:54:25.347	2026-05-20 08:44:58.65
c8e9e001-8c6e-4c55-8ef3-58a11b519a68	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-45BT3D của bạn đã được tiếp nhận.	{"code": "BAN-2026-45BT3D", "status": "ACCEPTED", "orderId": "f0c33315-a5c8-4b7c-a086-c9e828ceaa19"}	\N	2026-05-28 18:31:26.214
e3dddd60-d90c-4bae-a602-88d975446986	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đang chuẩn bị	Chúng tôi đang chuẩn bị đơn BAN-2026-45BT3D.	{"code": "BAN-2026-45BT3D", "status": "IN_PREPARATION", "orderId": "f0c33315-a5c8-4b7c-a086-c9e828ceaa19"}	\N	2026-05-28 18:31:26.387
d971221c-c0f1-4d05-b173-ac0206f2968a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Sẵn sàng để lấy	Đơn BAN-2026-45BT3D đã sẵn sàng để lấy!	{"code": "BAN-2026-45BT3D", "status": "READY_FOR_PICKUP", "orderId": "f0c33315-a5c8-4b7c-a086-c9e828ceaa19"}	\N	2026-05-28 18:31:26.55
4be8f631-2a77-465d-a36b-2e01395ed97b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-45BT3D. Chúc ngon miệng!	{"code": "BAN-2026-45BT3D", "status": "COMPLETED", "orderId": "f0c33315-a5c8-4b7c-a086-c9e828ceaa19"}	\N	2026-05-28 18:31:26.749
6c41bcaf-2cb8-47c2-9f3e-6472c5d46432	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-4E8HSA của bạn đã được tiếp nhận.	{"code": "BAN-2026-4E8HSA", "status": "ACCEPTED", "orderId": "94d6b88e-0960-442f-b479-fd1737296478"}	\N	2026-05-29 08:01:20.76
94bee447-adb2-48ba-a341-c6fc761477c5	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đang chuẩn bị	Chúng tôi đang chuẩn bị đơn BAN-2026-4E8HSA.	{"code": "BAN-2026-4E8HSA", "status": "IN_PREPARATION", "orderId": "94d6b88e-0960-442f-b479-fd1737296478"}	\N	2026-05-29 08:01:20.99
569a3a35-039d-4670-bc88-ab4d00552a5f	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Sẵn sàng để lấy	Đơn BAN-2026-4E8HSA đã sẵn sàng để lấy!	{"code": "BAN-2026-4E8HSA", "status": "READY_FOR_PICKUP", "orderId": "94d6b88e-0960-442f-b479-fd1737296478"}	\N	2026-05-29 08:01:21.185
07060543-b95b-4ec2-ab21-2e46cfdb419a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-4E8HSA. Chúc ngon miệng!	{"code": "BAN-2026-4E8HSA", "status": "COMPLETED", "orderId": "94d6b88e-0960-442f-b479-fd1737296478"}	\N	2026-05-29 08:01:21.457
e87090ac-a0a9-4638-9353-4855b48d2d50	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-V8F3Y9 của bạn đã được tiếp nhận.	{"code": "BAN-2026-V8F3Y9", "status": "ACCEPTED", "orderId": "f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c"}	\N	2026-05-29 08:01:22.142
00d564f9-13e8-4830-908a-783ed0cb626d	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đang chuẩn bị	Chúng tôi đang chuẩn bị đơn BAN-2026-V8F3Y9.	{"code": "BAN-2026-V8F3Y9", "status": "IN_PREPARATION", "orderId": "f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c"}	\N	2026-05-29 08:01:22.344
b1f4a22e-37cd-4877-828b-28b13969b073	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đang giao hàng	Đơn BAN-2026-V8F3Y9 đang trên đường giao!	{"code": "BAN-2026-V8F3Y9", "status": "DELIVERING", "orderId": "f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c"}	\N	2026-05-29 08:01:22.55
546091a1-2c19-48aa-9170-133ec93ed9f2	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-V8F3Y9. Chúc ngon miệng!	{"code": "BAN-2026-V8F3Y9", "status": "COMPLETED", "orderId": "f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c"}	\N	2026-05-29 08:01:22.82
89e2e3dd-a17a-42a1-b93b-9de8c92f24eb	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-LA522K của bạn đã được tiếp nhận.	{"code": "BAN-2026-LA522K", "status": "ACCEPTED", "orderId": "97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2"}	\N	2026-05-29 08:01:23.452
22c328b6-1d9f-40ad-a926-8cdad0068c86	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã chuyển bếp trung tâm	Đơn BAN-2026-LA522K đang được làm tại bếp trung tâm.	{"code": "BAN-2026-LA522K", "status": "SENT_TO_KITCHEN", "orderId": "97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2"}	\N	2026-05-29 08:01:23.679
2dc27450-ca41-4087-8d2f-394fec8ad1b5	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-ME4WSK	1 món · Lấy tại quầy	{"code": "BAN-2026-ME4WSK"}	\N	2026-06-04 14:11:21.31
c74b37c8-1ecb-45b7-ae50-62415fbe8240	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-SVDW4B	1 món · Lấy tại quầy	{"code": "BAN-2026-SVDW4B"}	\N	2026-06-04 14:24:51.19
7d4d309a-d1d8-44bf-b36a-08bdbec1338f	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Bếp đang làm	Đơn BAN-2026-LA522K hiện bếp đang làm.	{"code": "BAN-2026-LA522K", "orderId": "97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2", "kitchenStatus": "PREPARING"}	\N	2026-05-29 08:01:24.133
088358cc-7b4c-4818-895f-a296de26e596	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-X9RCYA của bạn đã được tiếp nhận.	{"code": "BAN-2026-X9RCYA", "status": "ACCEPTED", "orderId": "3dfa2152-e081-405f-af1c-01cf28f36833"}	\N	2026-05-29 08:01:25.654
d01dc726-0a59-40c1-927f-8085dbde77ac	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã chuyển bếp trung tâm	Đơn BAN-2026-X9RCYA đang được làm tại bếp trung tâm.	{"code": "BAN-2026-X9RCYA", "status": "SENT_TO_KITCHEN", "orderId": "3dfa2152-e081-405f-af1c-01cf28f36833"}	\N	2026-05-29 08:01:25.808
fa47d1a8-064c-4172-8920-0d8b98002681	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-X9RCYA. Chúc ngon miệng!	{"code": "BAN-2026-X9RCYA", "status": "COMPLETED", "orderId": "3dfa2152-e081-405f-af1c-01cf28f36833"}	\N	2026-05-29 08:01:26.508
66c23747-6812-45c4-af99-bc7f3ea05e52	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã chuyển bếp trung tâm	Đơn BAN-2026-BCGB9X đang được làm tại bếp trung tâm.	{"code": "BAN-2026-BCGB9X", "status": "SENT_TO_KITCHEN", "orderId": "333f3385-3ef1-468a-b268-0d58e4b8d4d5"}	\N	2026-05-29 08:01:27.294
e6792f84-a219-4cbb-b219-fa7bfa0e185e	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Sẵn sàng giao đi	Đơn BAN-2026-LA522K hiện sẵn sàng giao đi.	{"code": "BAN-2026-LA522K", "orderId": "97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2", "kitchenStatus": "READY_DISPATCH"}	\N	2026-05-29 08:01:24.588
6c016905-d878-4738-beeb-6d074a20af8c	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-LA522K. Chúc ngon miệng!	{"code": "BAN-2026-LA522K", "status": "COMPLETED", "orderId": "97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2"}	\N	2026-05-29 08:01:24.977
0c41d2a3-d190-4d8c-951d-d4b79326155f	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Bếp đang làm	Đơn BAN-2026-X9RCYA hiện bếp đang làm.	{"code": "BAN-2026-X9RCYA", "orderId": "3dfa2152-e081-405f-af1c-01cf28f36833", "kitchenStatus": "PREPARING"}	\N	2026-05-29 08:01:25.974
fc571529-7850-4f10-94d5-086667f623e0	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Sẵn sàng giao đi	Đơn BAN-2026-X9RCYA hiện sẵn sàng giao đi.	{"code": "BAN-2026-X9RCYA", "orderId": "3dfa2152-e081-405f-af1c-01cf28f36833", "kitchenStatus": "READY_DISPATCH"}	\N	2026-05-29 08:01:26.144
06303072-2f00-483d-b405-b481db5c980d	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-BCGB9X của bạn đã được tiếp nhận.	{"code": "BAN-2026-BCGB9X", "status": "ACCEPTED", "orderId": "333f3385-3ef1-468a-b268-0d58e4b8d4d5"}	\N	2026-05-29 08:01:27.123
2e0cd96a-2f31-40b3-b14a-22044f4d8510	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-XF973T của bạn đã được tiếp nhận.	{"code": "BAN-2026-XF973T", "status": "ACCEPTED", "orderId": "914b19c3-d8ad-46fe-a486-7ca8365ec2b7"}	\N	2026-05-29 08:01:28.071
a2b5767a-6e37-46c8-82a1-1ad7b624b809	3293c2bf-4ceb-4e45-8597-61bad26a4bad	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
c6e59e75-8baf-4dd7-9d44-32a758fb9af4	79e5bda1-a575-4b5f-9eca-d6fe2d91ea1f	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
bf470cc7-2673-47f4-b29a-05a228dc4428	0886d71a-9289-4444-a914-a6cf76832b64	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
76e9b01a-a6b7-44e2-9f51-c9e43fdcbee4	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
3a9155b2-0051-437d-b270-b0a3ff9cf3a2	1b9a0dcc-45a6-414c-b6ac-2140ee99d84d	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
754784c1-2d18-4a42-acd8-cd2102ceb987	63a01e12-3073-48e7-a620-900c0fcb2e28	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
61bf1af1-6142-40f1-b715-8a939c864abc	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
0fe37df8-742c-4b45-b1a5-f91a33354f00	9aa53cfd-c56a-4096-803a-f4b0d75bf805	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
399dd4c6-60e0-4ba4-aef3-2e6c3ff2b9af	783498ab-9459-4f48-869e-300495ef7bf9	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
0bfc2c71-c2f1-441d-8307-f569cae88cb6	61f1af85-9347-49d4-86a3-cb858d5a0b69	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
377d9ced-2fae-4515-a6c5-86d4a994c2fe	10291bfb-c4ed-463e-a626-09bed34891dd	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
075849e9-92d1-492e-8ed8-60785434d42a	5d28a394-1d64-4ae7-9b9b-3b6313b1686d	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
d8b5433a-107e-43e0-99a2-cd2f1cf6d667	f10163ab-fd73-4441-af99-8be5d9f4cc34	campaign	Khuy?n m�i cu?i tu?n	Gi?m 15% to�n b? b�nh sinh nh?t T7-CN n�y!	\N	\N	2026-06-02 08:48:08.307
6b6814e5-0b0b-497d-a887-e5ac1fd52769	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-93KNFS của bạn đã được tiếp nhận.	{"code": "BAN-2026-93KNFS", "status": "ACCEPTED", "orderId": "79696db8-7e3d-4408-89aa-d5010de88388"}	\N	2026-06-02 08:57:36.037
cd34f653-1537-47e4-8bf7-49e07f275de5	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đang chuẩn bị	Chúng tôi đang chuẩn bị đơn BAN-2026-93KNFS.	{"code": "BAN-2026-93KNFS", "status": "IN_PREPARATION", "orderId": "79696db8-7e3d-4408-89aa-d5010de88388"}	\N	2026-06-02 08:57:36.303
da51cdf6-519d-4df7-abb9-35e6da9aba98	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Sẵn sàng để lấy	Đơn BAN-2026-93KNFS đã sẵn sàng để lấy!	{"code": "BAN-2026-93KNFS", "status": "READY_FOR_PICKUP", "orderId": "79696db8-7e3d-4408-89aa-d5010de88388"}	\N	2026-06-02 08:57:36.547
4a7296c5-bb98-4a14-a9bf-6f77aad58b73	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-93KNFS. Chúc ngon miệng!	{"code": "BAN-2026-93KNFS", "status": "COMPLETED", "orderId": "79696db8-7e3d-4408-89aa-d5010de88388"}	\N	2026-06-02 08:57:36.797
c90ad1b5-912a-4ad3-9a04-d269c81eb4df	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-6JESW4 của bạn đã được tiếp nhận.	{"code": "BAN-2026-6JESW4", "status": "ACCEPTED", "orderId": "ef97c0c0-67be-4cce-aa98-efa1aa3a74bc"}	\N	2026-06-02 08:57:37.532
54c79cc3-d568-4ed0-b32d-dc8af5847f50	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đang chuẩn bị	Chúng tôi đang chuẩn bị đơn BAN-2026-6JESW4.	{"code": "BAN-2026-6JESW4", "status": "IN_PREPARATION", "orderId": "ef97c0c0-67be-4cce-aa98-efa1aa3a74bc"}	\N	2026-06-02 08:57:37.782
35096e34-4f2a-4b86-8b01-bb1cccf738d6	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đang giao hàng	Đơn BAN-2026-6JESW4 đang trên đường giao!	{"code": "BAN-2026-6JESW4", "status": "DELIVERING", "orderId": "ef97c0c0-67be-4cce-aa98-efa1aa3a74bc"}	\N	2026-06-02 08:57:38.019
ac58c38f-65ee-4c72-ba79-e9255b086dea	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-6JESW4. Chúc ngon miệng!	{"code": "BAN-2026-6JESW4", "status": "COMPLETED", "orderId": "ef97c0c0-67be-4cce-aa98-efa1aa3a74bc"}	\N	2026-06-02 08:57:38.307
2a23d00c-e9b0-405b-8ea8-20e2acfeb59c	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-ZFUU86 của bạn đã được tiếp nhận.	{"code": "BAN-2026-ZFUU86", "status": "ACCEPTED", "orderId": "22cb5aaf-7cd9-4483-8232-0209b84636b6"}	\N	2026-06-02 08:57:38.992
7d77cd42-245a-433c-b6fe-4966e6ac5ef0	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã chuyển bếp trung tâm	Đơn BAN-2026-ZFUU86 đang được làm tại bếp trung tâm.	{"code": "BAN-2026-ZFUU86", "status": "SENT_TO_KITCHEN", "orderId": "22cb5aaf-7cd9-4483-8232-0209b84636b6"}	\N	2026-06-02 08:57:39.235
5c6f6a92-2854-4bad-930f-e2507017283f	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Bếp đang làm	Đơn BAN-2026-ZFUU86 hiện bếp đang làm.	{"code": "BAN-2026-ZFUU86", "orderId": "22cb5aaf-7cd9-4483-8232-0209b84636b6", "kitchenStatus": "PREPARING"}	\N	2026-06-02 08:57:40.091
a51d2270-fc9a-427f-b39f-6eeb3a35349b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Sẵn sàng giao đi	Đơn BAN-2026-ZFUU86 hiện sẵn sàng giao đi.	{"code": "BAN-2026-ZFUU86", "orderId": "22cb5aaf-7cd9-4483-8232-0209b84636b6", "kitchenStatus": "READY_DISPATCH"}	\N	2026-06-02 08:57:40.449
68508bc3-cf73-4313-8b02-6f3d7e55a656	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-ZFUU86. Chúc ngon miệng!	{"code": "BAN-2026-ZFUU86", "status": "COMPLETED", "orderId": "22cb5aaf-7cd9-4483-8232-0209b84636b6"}	\N	2026-06-02 08:57:40.913
b2990e95-8e62-4b41-8b8d-4b4695f4229e	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-84N9Q3 của bạn đã được tiếp nhận.	{"code": "BAN-2026-84N9Q3", "status": "ACCEPTED", "orderId": "05c829ec-c0fd-41b1-9c05-102bd43439a6"}	\N	2026-06-02 08:57:41.675
5b1707fa-325c-44a8-b8de-d11e3093abd5	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã chuyển bếp trung tâm	Đơn BAN-2026-84N9Q3 đang được làm tại bếp trung tâm.	{"code": "BAN-2026-84N9Q3", "status": "SENT_TO_KITCHEN", "orderId": "05c829ec-c0fd-41b1-9c05-102bd43439a6"}	\N	2026-06-02 08:57:41.825
385986f7-01d0-4cf8-8e21-88a87bbc71c8	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Sẵn sàng giao đi	Đơn BAN-2026-84N9Q3 hiện sẵn sàng giao đi.	{"code": "BAN-2026-84N9Q3", "orderId": "05c829ec-c0fd-41b1-9c05-102bd43439a6", "kitchenStatus": "READY_DISPATCH"}	\N	2026-06-02 08:57:42.109
6b8cc1a9-7c2a-4bfd-be96-fef3efff8cb5	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-84N9Q3. Chúc ngon miệng!	{"code": "BAN-2026-84N9Q3", "status": "COMPLETED", "orderId": "05c829ec-c0fd-41b1-9c05-102bd43439a6"}	\N	2026-06-02 08:57:42.596
ff5c0ea4-02a8-4377-9888-772233a79853	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-G3JFDG của bạn đã được tiếp nhận.	{"code": "BAN-2026-G3JFDG", "status": "ACCEPTED", "orderId": "031479dc-1160-471b-a16f-cce9ff1625f6"}	\N	2026-06-02 08:57:43.171
a40d70e0-80f3-435c-a1a7-e38b7481908c	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã chuyển bếp trung tâm	Đơn BAN-2026-G3JFDG đang được làm tại bếp trung tâm.	{"code": "BAN-2026-G3JFDG", "status": "SENT_TO_KITCHEN", "orderId": "031479dc-1160-471b-a16f-cce9ff1625f6"}	\N	2026-06-02 08:57:43.311
855adce8-44a1-47d1-bd40-aed73af07f30	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đơn đã huỷ	Đơn BAN-2026-P3YS8Q đã bị huỷ.	{"code": "BAN-2026-P3YS8Q", "status": "CANCELLED", "orderId": "d65f2099-6c4d-456c-8dc2-87d357842f4c"}	\N	2026-06-02 08:57:43.921
00545f09-ed27-4c73-a749-463e6e988e96	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đơn đã huỷ	Đơn BAN-2026-HSUU8W đã bị huỷ.	{"code": "BAN-2026-HSUU8W", "status": "CANCELLED", "orderId": "a3236cb6-463b-4402-8bc7-fcbd666257d6"}	\N	2026-06-02 08:57:44.844
70c27eb2-4a5d-4af8-ba5b-b59c64e17120	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Bếp đang làm	Đơn BAN-2026-84N9Q3 hiện bếp đang làm.	{"code": "BAN-2026-84N9Q3", "orderId": "05c829ec-c0fd-41b1-9c05-102bd43439a6", "kitchenStatus": "PREPARING"}	\N	2026-06-02 08:57:41.964
3bce8e77-b5a0-4dd7-b248-bd96fe43d9a5	3293c2bf-4ceb-4e45-8597-61bad26a4bad	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
5f903e18-0607-4fe1-b744-4c5af73dd522	79e5bda1-a575-4b5f-9eca-d6fe2d91ea1f	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
49b612fa-201f-408d-a471-6c02b30e0177	0886d71a-9289-4444-a914-a6cf76832b64	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
c8e2da39-97f6-40a7-a5f9-8cd577fc1710	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
edb01fa5-d45c-46b0-ba16-ec043c4dff36	1b9a0dcc-45a6-414c-b6ac-2140ee99d84d	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
2ab02bdc-c1b8-4039-ba95-60cd323da7be	63a01e12-3073-48e7-a620-900c0fcb2e28	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
bce4e448-2ebd-409d-8b2b-f428d407252b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
e1886cf5-0b89-4d7b-9e3e-2533ce3c90e2	9aa53cfd-c56a-4096-803a-f4b0d75bf805	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
80979588-4186-4fc8-b512-ca3f5a612941	783498ab-9459-4f48-869e-300495ef7bf9	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
9d82e3c3-8334-4d19-a7f3-9b9823213b68	61f1af85-9347-49d4-86a3-cb858d5a0b69	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
ead7e24c-85f2-4442-93a9-a91ff3246258	10291bfb-c4ed-463e-a626-09bed34891dd	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
b87b872b-366e-4e28-992c-39498cd4be35	5d28a394-1d64-4ae7-9b9b-3b6313b1686d	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
a845f280-0aa5-473f-9dfd-cce7972e86e1	f10163ab-fd73-4441-af99-8be5d9f4cc34	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
b2cfbf32-92cc-4498-9663-4e66051a4d9f	d70495ff-161a-4f2b-a817-540ca2658367	campaign	FCMTEST-BROADCAST-23442	kiem tra push	\N	\N	2026-06-02 10:34:24.613
fbc2e27e-0b4f-463a-8e1e-d77033a41298	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-7CTCY4 của bạn đã được tiếp nhận.	{"code": "BAN-2026-7CTCY4", "status": "ACCEPTED", "orderId": "f5158425-e1b1-48a9-bca8-8e4bf4fa337d"}	\N	2026-06-02 10:34:27.383
e99034d7-3de7-42cb-bcef-4f0697e744a0	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	merchant.message	asdf	asdfasdf	null	\N	2026-06-02 10:36:16.383
0981bc69-eee3-49a2-a109-d72f36b68898	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-DKH3QH	1 món · Lấy tại quầy	{"code": "BAN-2026-DKH3QH"}	\N	2026-06-02 10:54:09.894
9c26d10f-0c6d-476b-ae34-7f445db3194b	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-DKH3QH	1 món · Lấy tại quầy	{"code": "BAN-2026-DKH3QH"}	\N	2026-06-02 10:54:09.906
2ca2d7e5-f8e0-475d-b2c2-007f87f0730a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-DKH3QH của bạn đã được tiếp nhận.	{"code": "BAN-2026-DKH3QH", "status": "ACCEPTED", "orderId": "a70eece6-5748-4365-a6ab-990aaf2249cf"}	\N	2026-06-02 10:54:10.297
ff538090-80bf-4d37-b658-3bba73175d2d	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã chuyển bếp trung tâm	Đơn BAN-2026-DKH3QH đang được làm tại bếp trung tâm.	{"code": "BAN-2026-DKH3QH", "status": "SENT_TO_KITCHEN", "orderId": "a70eece6-5748-4365-a6ab-990aaf2249cf"}	\N	2026-06-02 10:54:10.441
68285560-9968-4a01-bccb-c52ad5edf48e	ab32baa0-382d-48e5-a542-b6f6a3620a9b	kitchen_new	Đơn vào bếp · BAN-2026-DKH3QH	1 món cần chuẩn bị.	{"code": "BAN-2026-DKH3QH"}	\N	2026-06-02 10:54:10.456
a307c053-1a44-4761-b656-bc669beb28a5	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Bếp đang làm	Đơn BAN-2026-BCGB9X hiện bếp đang làm.	{"code": "BAN-2026-BCGB9X", "orderId": "333f3385-3ef1-468a-b268-0d58e4b8d4d5", "kitchenStatus": "PREPARING"}	\N	2026-06-02 11:05:41.474
0ba2ef51-bc76-4d15-bb45-848802160875	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Bếp đang làm	Đơn BAN-2026-G3JFDG hiện bếp đang làm.	{"code": "BAN-2026-G3JFDG", "orderId": "031479dc-1160-471b-a16f-cce9ff1625f6", "kitchenStatus": "PREPARING"}	\N	2026-06-02 11:05:56.969
36e5fb3d-15af-4e46-889e-02099cc514b5	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Bếp đang làm	Đơn BAN-2026-DKH3QH hiện bếp đang làm.	{"code": "BAN-2026-DKH3QH", "orderId": "a70eece6-5748-4365-a6ab-990aaf2249cf", "kitchenStatus": "PREPARING"}	\N	2026-06-02 11:05:58.217
5d7c6432-fd0b-4216-9d24-2b74b41edff8	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Sẵn sàng giao đi	Đơn BAN-2026-BCGB9X hiện sẵn sàng giao đi.	{"code": "BAN-2026-BCGB9X", "orderId": "333f3385-3ef1-468a-b268-0d58e4b8d4d5", "kitchenStatus": "READY_DISPATCH"}	\N	2026-06-02 11:06:17.082
09447963-1b41-4c84-a035-b5fbd5c013ed	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Sẵn sàng để lấy	Đơn BAN-2026-BCGB9X đã sẵn sàng để lấy!	{"code": "BAN-2026-BCGB9X", "status": "READY_FOR_PICKUP", "orderId": "333f3385-3ef1-468a-b268-0d58e4b8d4d5"}	\N	2026-06-02 11:06:29.757
4454b4b5-afde-4a02-ae86-f5216422d81f	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Sẵn sàng giao đi	Đơn BAN-2026-G3JFDG hiện sẵn sàng giao đi.	{"code": "BAN-2026-G3JFDG", "orderId": "031479dc-1160-471b-a16f-cce9ff1625f6", "kitchenStatus": "READY_DISPATCH"}	\N	2026-06-02 11:06:31.013
bf25f7e6-3c0c-4010-bb13-e3bbc5e4e349	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Sẵn sàng giao đi	Đơn BAN-2026-DKH3QH hiện sẵn sàng giao đi.	{"code": "BAN-2026-DKH3QH", "orderId": "a70eece6-5748-4365-a6ab-990aaf2249cf", "kitchenStatus": "READY_DISPATCH"}	\N	2026-06-02 11:06:31.669
23730a6c-420f-4008-824e-fb317ca5ea0c	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Sẵn sàng để lấy	Đơn BAN-2026-G3JFDG đã sẵn sàng để lấy!	{"code": "BAN-2026-G3JFDG", "status": "READY_FOR_PICKUP", "orderId": "031479dc-1160-471b-a16f-cce9ff1625f6"}	\N	2026-06-02 11:06:32.354
a53137ae-2fca-41ea-81bd-cee80423f537	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Sẵn sàng để lấy	Đơn BAN-2026-DKH3QH đã sẵn sàng để lấy!	{"code": "BAN-2026-DKH3QH", "status": "READY_FOR_PICKUP", "orderId": "a70eece6-5748-4365-a6ab-990aaf2249cf"}	\N	2026-06-02 11:06:33.324
2d6de250-58f7-47d6-a6b2-d14a059f1aea	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-P37JDU	1 món · Lấy tại quầy	{"code": "BAN-2026-P37JDU"}	\N	2026-06-02 11:09:20.469
4a1757ec-6d3b-4ad8-b8e5-bbb06a93f017	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-P37JDU	1 món · Lấy tại quầy	{"code": "BAN-2026-P37JDU"}	\N	2026-06-02 11:09:20.475
f2ed969b-1e08-4ec9-87d5-cad91a4575fe	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-LQPC7H	1 món · Giao hàng	{"code": "BAN-2026-LQPC7H"}	\N	2026-06-02 11:09:20.62
071d6014-ca82-4300-98c3-eb0449e92199	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-LQPC7H	1 món · Giao hàng	{"code": "BAN-2026-LQPC7H"}	\N	2026-06-02 11:09:20.624
3efecbc3-f49e-4742-9465-c39f1f0648df	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-TW7F9N	1 món · Lấy tại quầy	{"code": "BAN-2026-TW7F9N"}	\N	2026-06-04 14:25:16.152
4da1539b-b465-46c7-9d08-f33fa26f2bbe	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-PXSU99	1 món · Lấy tại quầy	{"code": "BAN-2026-PXSU99"}	\N	2026-06-04 14:25:16.461
02ee4d91-fc46-4ae6-8c46-51a6e263b900	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-QGC8DL	2 món · Lấy tại quầy	{"code": "BAN-2026-QGC8DL"}	\N	2026-06-04 14:25:17.043
a4797beb-4a86-4449-8ff1-3fac1fccb5a8	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-A6F9WW	1 món · Giao hàng	{"code": "BAN-2026-A6F9WW"}	\N	2026-06-04 14:25:18.206
47531958-c7a8-43c3-8dfb-14e40bf705c4	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-F48DNC	1 món · Lấy tại quầy	{"code": "BAN-2026-F48DNC"}	\N	2026-06-04 14:25:18.763
bae3c4ee-02d3-446c-84b7-9361465bfb14	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đang chuẩn bị	Chúng tôi đang chuẩn bị đơn BAN-2026-F48DNC.	{"code": "BAN-2026-F48DNC", "status": "IN_PREPARATION", "orderId": "5066a015-de2b-4f75-acac-357c4ade16cd"}	\N	2026-06-04 14:25:19.502
d0d96fce-7c6d-4040-a3f5-d26ef87e5b86	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-F48DNC. Chúc ngon miệng!	{"code": "BAN-2026-F48DNC", "status": "COMPLETED", "orderId": "5066a015-de2b-4f75-acac-357c4ade16cd"}	\N	2026-06-04 14:25:19.883
091c8042-f6cb-42bd-9a7f-13366a576c06	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-PCNBQ9	1 món · Giao hàng	{"code": "BAN-2026-PCNBQ9"}	\N	2026-06-04 14:25:20.155
6af31a84-9b78-4aa7-93fc-7bf05b635261	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-PCNBQ9 của bạn đã được tiếp nhận.	{"code": "BAN-2026-PCNBQ9", "status": "ACCEPTED", "orderId": "c4b3e273-2560-4dab-ab8a-64c3afb68727"}	\N	2026-06-04 14:25:20.562
8d4ed587-d8e7-4cbf-81a8-97b30df2e561	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đang giao hàng	Đơn BAN-2026-PCNBQ9 đang trên đường giao!	{"code": "BAN-2026-PCNBQ9", "status": "DELIVERING", "orderId": "c4b3e273-2560-4dab-ab8a-64c3afb68727"}	\N	2026-06-04 14:25:20.944
a8905c54-f75d-4fff-8112-54103b143982	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-NDMF2R	1 món · Lấy tại quầy	{"code": "BAN-2026-NDMF2R"}	\N	2026-06-04 14:25:21.372
ef5e5191-d886-4894-bff0-5b3b13da15c0	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã chuyển bếp trung tâm	Đơn BAN-2026-NDMF2R đang được làm tại bếp trung tâm.	{"code": "BAN-2026-NDMF2R", "status": "SENT_TO_KITCHEN", "orderId": "6a92f954-1fb8-4cbd-a9aa-7423dde45627"}	\N	2026-06-04 14:25:21.944
f8535df4-ad33-496a-8c22-bce1f4f30440	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Sẵn sàng giao đi	Đơn BAN-2026-PNM4ZM hiện sẵn sàng giao đi.	{"code": "BAN-2026-PNM4ZM", "orderId": "4831b162-0d0d-40df-a1b9-5360d034f731", "kitchenStatus": "READY_DISPATCH"}	\N	2026-06-04 14:25:24.369
49e1d3cb-db02-456c-a5bc-261aa93cf358	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-W6MBWV	1 món · Lấy tại quầy	{"code": "BAN-2026-W6MBWV"}	\N	2026-06-04 14:25:24.937
417ce99e-c813-4c86-a6f0-73c59e683e5a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã chuyển bếp trung tâm	Đơn BAN-2026-W6MBWV đang được làm tại bếp trung tâm.	{"code": "BAN-2026-W6MBWV", "status": "SENT_TO_KITCHEN", "orderId": "932e0a80-ad20-4c57-87e1-45770d409aa7"}	\N	2026-06-04 14:25:25.306
f4618293-569e-48a1-9adf-7912309f9bb8	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-TW7F9N	1 món · Lấy tại quầy	{"code": "BAN-2026-TW7F9N"}	\N	2026-06-04 14:25:16.157
3f207af1-53a9-4642-9a46-2596fd547d58	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-PXSU99	1 món · Lấy tại quầy	{"code": "BAN-2026-PXSU99"}	\N	2026-06-04 14:25:16.458
611582eb-d104-47e0-b297-fc5d3469c9db	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-QGC8DL	2 món · Lấy tại quầy	{"code": "BAN-2026-QGC8DL"}	\N	2026-06-04 14:25:17.046
5edb71b0-411c-4115-81b8-427c93d82beb	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-89F2GQ	1 món · Lấy tại quầy	{"code": "BAN-2026-89F2GQ"}	\N	2026-06-04 14:25:17.848
b479f3c4-4b05-4c89-9b45-a9c4e03bc854	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-89F2GQ	1 món · Lấy tại quầy	{"code": "BAN-2026-89F2GQ"}	\N	2026-06-04 14:25:17.854
f375224b-54c8-4068-9384-28e034e0c9ea	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-A6F9WW	1 món · Giao hàng	{"code": "BAN-2026-A6F9WW"}	\N	2026-06-04 14:25:18.2
a2744ffe-36ca-430e-b899-9bbb17a08e90	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-F48DNC	1 món · Lấy tại quầy	{"code": "BAN-2026-F48DNC"}	\N	2026-06-04 14:25:18.768
c1566f4d-912e-455a-9542-511946870ed8	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-F48DNC của bạn đã được tiếp nhận.	{"code": "BAN-2026-F48DNC", "status": "ACCEPTED", "orderId": "5066a015-de2b-4f75-acac-357c4ade16cd"}	\N	2026-06-04 14:25:19.313
2df70261-87ef-47e8-bc61-6b01b20c6b8c	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Sẵn sàng để lấy	Đơn BAN-2026-F48DNC đã sẵn sàng để lấy!	{"code": "BAN-2026-F48DNC", "status": "READY_FOR_PICKUP", "orderId": "5066a015-de2b-4f75-acac-357c4ade16cd"}	\N	2026-06-04 14:25:19.669
9a074e43-073b-467b-9d38-0fb0b77ff9d1	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-PCNBQ9	1 món · Giao hàng	{"code": "BAN-2026-PCNBQ9"}	\N	2026-06-04 14:25:20.149
46919c7f-684d-439a-b5c1-3cdad034f812	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đang chuẩn bị	Chúng tôi đang chuẩn bị đơn BAN-2026-PCNBQ9.	{"code": "BAN-2026-PCNBQ9", "status": "IN_PREPARATION", "orderId": "c4b3e273-2560-4dab-ab8a-64c3afb68727"}	\N	2026-06-04 14:25:20.765
16e72e7a-a08e-4178-9406-76a673b7c557	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-PCNBQ9. Chúc ngon miệng!	{"code": "BAN-2026-PCNBQ9", "status": "COMPLETED", "orderId": "c4b3e273-2560-4dab-ab8a-64c3afb68727"}	\N	2026-06-04 14:25:21.171
dd748d52-91fe-4d28-b636-331cef89bd48	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-NDMF2R	1 món · Lấy tại quầy	{"code": "BAN-2026-NDMF2R"}	\N	2026-06-04 14:25:21.378
b1cf732e-020e-4c65-80ce-06ad8bfd6664	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-NDMF2R của bạn đã được tiếp nhận.	{"code": "BAN-2026-NDMF2R", "status": "ACCEPTED", "orderId": "6a92f954-1fb8-4cbd-a9aa-7423dde45627"}	\N	2026-06-04 14:25:21.737
222ec5fb-b512-4a03-a4d3-f78c3d5a9779	ab32baa0-382d-48e5-a542-b6f6a3620a9b	kitchen_new	Đơn vào bếp · BAN-2026-NDMF2R	1 món cần chuẩn bị.	{"code": "BAN-2026-NDMF2R"}	\N	2026-06-04 14:25:21.953
99c51de8-a07f-442b-a048-bd66c71611b8	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Bếp đang làm	Đơn BAN-2026-NDMF2R hiện bếp đang làm.	{"code": "BAN-2026-NDMF2R", "orderId": "6a92f954-1fb8-4cbd-a9aa-7423dde45627", "kitchenStatus": "PREPARING"}	\N	2026-06-04 14:25:22.404
d79e0348-b025-42d5-9065-88b32e69efa3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Sẵn sàng giao đi	Đơn BAN-2026-NDMF2R hiện sẵn sàng giao đi.	{"code": "BAN-2026-NDMF2R", "orderId": "6a92f954-1fb8-4cbd-a9aa-7423dde45627", "kitchenStatus": "READY_DISPATCH"}	\N	2026-06-04 14:25:22.817
a5adf186-7230-4358-88bc-3afc11b96591	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Sẵn sàng để lấy	Đơn BAN-2026-NDMF2R đã sẵn sàng để lấy!	{"code": "BAN-2026-NDMF2R", "status": "READY_FOR_PICKUP", "orderId": "6a92f954-1fb8-4cbd-a9aa-7423dde45627"}	\N	2026-06-04 14:25:23.044
96e12f42-cf5c-45b0-95ae-958edef2ba83	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-NDMF2R. Chúc ngon miệng!	{"code": "BAN-2026-NDMF2R", "status": "COMPLETED", "orderId": "6a92f954-1fb8-4cbd-a9aa-7423dde45627"}	\N	2026-06-04 14:25:23.285
3c3e5a65-2d07-4d1c-85d4-5b7a2be7b2d3	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-PNM4ZM	1 món · Giao hàng	{"code": "BAN-2026-PNM4ZM"}	\N	2026-06-04 14:25:23.55
918072b9-81e5-47b4-b3d5-eb1c75663205	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-PNM4ZM	1 món · Giao hàng	{"code": "BAN-2026-PNM4ZM"}	\N	2026-06-04 14:25:23.555
19905e12-fbe4-4a14-9c3a-ea2026b0dedf	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-PNM4ZM của bạn đã được tiếp nhận.	{"code": "BAN-2026-PNM4ZM", "status": "ACCEPTED", "orderId": "4831b162-0d0d-40df-a1b9-5360d034f731"}	\N	2026-06-04 14:25:23.953
72243e77-2edb-40a7-8221-51da909b376d	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã chuyển bếp trung tâm	Đơn BAN-2026-PNM4ZM đang được làm tại bếp trung tâm.	{"code": "BAN-2026-PNM4ZM", "status": "SENT_TO_KITCHEN", "orderId": "4831b162-0d0d-40df-a1b9-5360d034f731"}	\N	2026-06-04 14:25:24.096
ff5904ef-c55b-4422-aeec-00b031698854	ab32baa0-382d-48e5-a542-b6f6a3620a9b	kitchen_new	Đơn vào bếp · BAN-2026-PNM4ZM	1 món cần chuẩn bị.	{"code": "BAN-2026-PNM4ZM"}	\N	2026-06-04 14:25:24.102
f7058419-87ad-43f8-8511-9bb2bb4f612a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.kitchen_status_changed	Bếp đang làm	Đơn BAN-2026-PNM4ZM hiện bếp đang làm.	{"code": "BAN-2026-PNM4ZM", "orderId": "4831b162-0d0d-40df-a1b9-5360d034f731", "kitchenStatus": "PREPARING"}	\N	2026-06-04 14:25:24.238
50729cee-158d-4efa-8356-3fdea6543ee4	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đang giao hàng	Đơn BAN-2026-PNM4ZM đang trên đường giao!	{"code": "BAN-2026-PNM4ZM", "status": "DELIVERING", "orderId": "4831b162-0d0d-40df-a1b9-5360d034f731"}	\N	2026-06-04 14:25:24.504
eb1489d9-9429-4cb1-adc5-02b723541ddb	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Hoàn tất đơn hàng	Cảm ơn bạn đã đặt đơn BAN-2026-PNM4ZM. Chúc ngon miệng!	{"code": "BAN-2026-PNM4ZM", "status": "COMPLETED", "orderId": "4831b162-0d0d-40df-a1b9-5360d034f731"}	\N	2026-06-04 14:25:24.719
00c12b88-8714-4efc-92ba-be4ab930bc40	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-W6MBWV	1 món · Lấy tại quầy	{"code": "BAN-2026-W6MBWV"}	\N	2026-06-04 14:25:24.941
4ab16e36-032f-46ac-bc80-0605e9ca767b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-W6MBWV của bạn đã được tiếp nhận.	{"code": "BAN-2026-W6MBWV", "status": "ACCEPTED", "orderId": "932e0a80-ad20-4c57-87e1-45770d409aa7"}	\N	2026-06-04 14:25:25.176
ce1768de-fbf5-4bd1-a7e5-9d10bfe445ed	ab32baa0-382d-48e5-a542-b6f6a3620a9b	kitchen_new	Đơn vào bếp · BAN-2026-W6MBWV	1 món cần chuẩn bị.	{"code": "BAN-2026-W6MBWV"}	\N	2026-06-04 14:25:25.315
4b07b4ff-9f48-4abd-9b66-939e157a7836	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-D8KH6E	1 món · Lấy tại quầy	{"code": "BAN-2026-D8KH6E"}	\N	2026-06-04 14:25:25.563
99957c32-3cb5-47cf-89e0-4500e3477c2b	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-4WDK3E	1 món · Lấy tại quầy	{"code": "BAN-2026-4WDK3E"}	\N	2026-06-04 14:25:26.225
0d63e163-0f47-4e77-9b63-b1ac14c32da7	3293c2bf-4ceb-4e45-8597-61bad26a4bad	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
23c3f680-9140-410c-8087-016d0775261c	79e5bda1-a575-4b5f-9eca-d6fe2d91ea1f	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
33adee70-a505-4009-ba9b-0bf420912543	0886d71a-9289-4444-a914-a6cf76832b64	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
5e8486ba-21b4-4e68-a7ee-8a11f5cdc225	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
cf88cbb2-8473-4d35-a14c-af5b008a213d	1b9a0dcc-45a6-414c-b6ac-2140ee99d84d	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
a34e7213-0e29-4a9a-9ffd-a09f808cca67	63a01e12-3073-48e7-a620-900c0fcb2e28	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
2656b7de-2922-47b5-b16d-d4e615c2d1ec	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
4fa6197d-495f-4d4b-9412-ea63431848b3	9aa53cfd-c56a-4096-803a-f4b0d75bf805	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
fe885795-f965-4fe1-98ee-ac5a984ebf26	783498ab-9459-4f48-869e-300495ef7bf9	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
4f988b66-4384-46db-9b60-6ef22f81ada3	61f1af85-9347-49d4-86a3-cb858d5a0b69	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
62ed0c50-898a-488f-94d5-27d0f0f3cfbe	10291bfb-c4ed-463e-a626-09bed34891dd	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
ede0c71f-be52-4794-90ec-29a5f4b1332e	5d28a394-1d64-4ae7-9b9b-3b6313b1686d	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
23e18e1f-618a-4bbf-bbad-a02f4b222d9b	f10163ab-fd73-4441-af99-8be5d9f4cc34	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
bf5ad507-57a5-4463-935d-05d4dd67b06f	d70495ff-161a-4f2b-a817-540ca2658367	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
3f0dc68b-7d3f-4293-80ed-13909dd0788c	0502db59-3b85-40bc-9325-3556c61967c1	campaign	FCMTEST-BROADCAST-6433	kiem tra push	\N	\N	2026-06-04 14:25:39.335
b48fcba8-37de-4313-b49a-d36696646be8	90d6537e-9af8-48c1-8c44-acc1bac26dec	order_new	Đơn mới · BAN-2026-ZP6PZT	1 món · Lấy tại quầy	{"code": "BAN-2026-ZP6PZT"}	\N	2026-06-04 14:25:41.788
e2abebab-4c6b-4e67-8191-4aa134d773ec	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-D8KH6E	1 món · Lấy tại quầy	{"code": "BAN-2026-D8KH6E"}	\N	2026-06-04 14:25:25.568
344a7a2b-e6e0-44e8-9d78-c7e2c8955cfc	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đơn đã huỷ	Đơn BAN-2026-D8KH6E đã bị huỷ.	{"code": "BAN-2026-D8KH6E", "status": "CANCELLED", "orderId": "31e11ed9-a86d-4403-97f4-0ad0fda04556"}	\N	2026-06-04 14:25:25.853
be663cd2-22d3-4d4c-a9d0-74125465782e	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-4WDK3E	1 món · Lấy tại quầy	{"code": "BAN-2026-4WDK3E"}	\N	2026-06-04 14:25:26.229
2505bfe0-ea80-4260-bf3f-be54b8e48d18	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đơn đã huỷ	Đơn BAN-2026-4WDK3E đã bị huỷ.	{"code": "BAN-2026-4WDK3E", "status": "CANCELLED", "orderId": "7b4a9ff3-9a49-4b5d-84ac-8ce47f65a291"}	\N	2026-06-04 14:25:26.649
20580688-41e6-49d5-9221-7bc242b753f1	7858ce6f-8e76-41a7-8389-296144e78f8f	order_new	Đơn mới · BAN-2026-ZP6PZT	1 món · Lấy tại quầy	{"code": "BAN-2026-ZP6PZT"}	\N	2026-06-04 14:25:41.794
a170fa1e-d977-42a2-a64c-4ec7851f48ef	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	order.status_changed	Đã nhận đơn	Đơn BAN-2026-ZP6PZT của bạn đã được tiếp nhận.	{"code": "BAN-2026-ZP6PZT", "status": "ACCEPTED", "orderId": "cf3c0c8e-40aa-4025-9580-b4c941f82ece"}	\N	2026-06-04 14:25:42.05
\.


ALTER TABLE public."Notification" ENABLE TRIGGER ALL;

--
-- Data for Name: OrderItem; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."OrderItem" DISABLE TRIGGER ALL;

COPY public."OrderItem" (id, "orderId", "productId", "variantId", "productName", "variantLabel", quantity, "unitPrice", "customMessage", "lineTotal", personalization) FROM stdin;
c5448c1e-be81-4a56-a6b1-14e02a32287a	36cb2b2b-f0e8-44b5-bc59-23931e320913	1f8182e6-f0a1-4aa4-b920-8b509d66811f	cdaf2925-8d37-4ec0-8c63-c607e4805d19	Tarte au Citron	Individual · Lemon	1	240000.00	\N	240000.00	\N
9f94ab39-a9c6-445d-a186-661ab297f7ed	060470be-e651-4d99-b519-9ea5491effd9	1f8182e6-f0a1-4aa4-b920-8b509d66811f	cdaf2925-8d37-4ec0-8c63-c607e4805d19	Tarte au Citron	Individual · Lemon	1	240000.00	\N	240000.00	\N
37c8b992-330e-4f83-a019-ccc58af66cf0	c47b501f-763d-4a2d-bf4b-2377d8c39b6f	4f5c100d-3315-4629-ac91-6fceffeb2c8d	21b61875-681b-456a-bbbc-78e5a940649d	Mango Passion (Summer)	6" · Mango Passion	1	420000.00	\N	420000.00	\N
eb8a011a-f6b9-4644-982c-86e0cd6476dd	54081945-a072-4dc5-924c-60aa005a4344	462abcbd-bedd-40c5-9dcf-b840d829fdbe	c904f21b-bfad-45c5-8201-3eb573fdf1bf	Rose Lychee Mousse	8" · Rose Lychee	1	560000.00	\N	560000.00	\N
93358d38-b4e5-4f7d-b6a0-830c04d1e4cb	a2476e33-44d3-4c2b-ad4d-798099f6522c	1f8182e6-f0a1-4aa4-b920-8b509d66811f	cdaf2925-8d37-4ec0-8c63-c607e4805d19	Tarte au Citron	Individual · Lemon	1	240000.00	\N	240000.00	\N
044dfcd0-442f-4bbd-952a-ec642aaad400	7da53799-e88f-459c-b0ec-c988e7d8793a	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	\N
6433a959-bc67-4a19-958b-ae1d79959a4e	0a6067cb-cfb2-4be0-b5c7-4d98fe27129e	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	\N
c04acb9a-cb63-4ece-8290-4cb66180333e	c573a2c0-ab99-4fe5-a4fb-6807a578688c	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	\N
a6d9e1be-1340-4b42-acb7-d8558bedacbb	71fa0429-dd11-429a-8d10-6444d48180df	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	\N
5a32ecf9-38b6-4eb4-93cb-b865169e146b	1e848d09-56e4-4f97-892a-491cbed7c625	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	\N
fd409142-869a-4256-9bcb-9eb37f63247e	c2a3e00d-5319-4144-84b4-eff3d58b0659	4f5c100d-3315-4629-ac91-6fceffeb2c8d	\N	Mango Passion (Summer)	6" · Mango Passion	1	420000.00	\N	420000.00	\N
1c5c0684-774e-4ec2-a041-8ceb25064c10	048a1b04-4f67-4b24-9056-5fa16c1d0b0f	4f5c100d-3315-4629-ac91-6fceffeb2c8d	\N	Mango Passion (Summer)	6" · Mango Passion	1	420000.00	\N	420000.00	\N
1dfdcc74-87b7-4ad8-8899-cc843611312d	2e5da661-e48b-4e68-b7cd-5b5397bc3d54	4f5c100d-3315-4629-ac91-6fceffeb2c8d	\N	Mango Passion (Summer)	6" · Mango Passion	1	420000.00	\N	420000.00	\N
936a0310-6d9b-44a8-b4f8-d9bd98657171	f0a0d840-5792-4d71-bb97-b1bfb80ed10d	4f5c100d-3315-4629-ac91-6fceffeb2c8d	\N	Mango Passion (Summer)	8" · Mango Passion	1	620000.00	\N	620000.00	\N
87425230-70c0-409d-b7e2-5c54b5edc4e2	bda681ec-e669-4029-b6f6-31f823328307	4f5c100d-3315-4629-ac91-6fceffeb2c8d	\N	Mango Passion (Summer)	8" · Mango Passion	1	620000.00	\N	620000.00	\N
5d9af7bf-76a3-44aa-bafe-ff3ddfa854c5	89fab936-1cc9-4b40-b4c5-be0c4b54109f	4f5c100d-3315-4629-ac91-6fceffeb2c8d	\N	Mango Passion (Summer)	8" · Mango Passion	1	620000.00	\N	620000.00	\N
1f905c0c-356b-42a3-854f-b3ef88af5212	d8789680-e784-4186-8c35-27863524ca68	1f8182e6-f0a1-4aa4-b920-8b509d66811f	\N	Tarte au Citron	Individual · Lemon	1	240000.00	\N	240000.00	\N
42a7cb59-cc54-4990-97c1-a1ca74ca98de	81d4c479-c7be-46fd-8181-6dc4616541bb	1f8182e6-f0a1-4aa4-b920-8b509d66811f	\N	Tarte au Citron	Individual · Lemon	1	240000.00	\N	240000.00	\N
1fadb43f-be1b-4665-8967-aceafac1deeb	0cf1fecb-9856-447c-8a88-3bd8adff8bc9	1f8182e6-f0a1-4aa4-b920-8b509d66811f	\N	Tarte au Citron	Individual · Lemon	1	240000.00	\N	240000.00	\N
9c02385f-f3b8-40ea-9dd1-a1d723aeadcd	322fdd05-ee34-4cbe-8f99-e5eb37ed5314	1f8182e6-f0a1-4aa4-b920-8b509d66811f	\N	Tarte au Citron	Individual · Lemon	1	240000.00	\N	240000.00	\N
515bb75f-a2dd-4b80-a59c-11bc73414a7f	2d79c95b-ce16-459d-91cf-53d1f39edc4a	1f8182e6-f0a1-4aa4-b920-8b509d66811f	cdaf2925-8d37-4ec0-8c63-c607e4805d19	Tarte au Citron	Individual · Lemon	1	240000.00	\N	240000.00	\N
d428f46a-a081-4cfe-9e03-7f6a515f7c0a	cff6b826-0ffa-4458-96bb-ca30dd0e310b	1f8182e6-f0a1-4aa4-b920-8b509d66811f	cdaf2925-8d37-4ec0-8c63-c607e4805d19	Tarte au Citron	Individual · Lemon	1	240000.00	\N	240000.00	\N
21611995-5c28-46e9-811d-38bb1540bf41	06d2dfdf-83cb-4485-95f4-e83287e72c6f	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	\N
ff28d7b0-1286-45e6-99da-34980aa776dc	8b0aaca7-6e78-4010-b988-cc241b9f0e34	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	\N
d683786b-8fb5-4f56-a857-6811fc101fd7	3c3a9c52-ccfd-4669-ae34-b8c1ab660813	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	\N
247940b5-b16f-498d-a529-90b24da0f258	ea013a43-7376-4e96-aaa1-04eee039bf28	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	\N
d8a05966-7be3-41e4-84bc-c3c43c675f4f	7fd35beb-5d8a-4f76-b6f8-125abe027dc2	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	\N
4896ac03-90ec-4938-9ce1-bbe96f713e8d	360b1f6b-906b-49db-b7e3-67541b684874	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	\N
7762835e-b08f-48b1-9d6e-f1510a775121	f4221321-a57b-4002-a94f-0d93688d71c1	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	\N
94d16dd9-fc14-4c04-ab62-11e24fe9a8bb	71e6adfe-e78e-454c-adb3-bee43493df48	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	\N
6487124f-f486-46de-affb-f7b4dda1c4b1	415d8f50-24cc-47ad-a356-e65c5a126a36	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	\N
119d4297-dbeb-405d-97d8-6fd2283b0035	930a41c4-0cd0-44a3-80d0-f1dec0a7987d	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	\N
83888524-a2bc-4f6a-9882-c5ca167fd3ab	f416ccc5-c756-4486-a4f6-21000213936e	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	\N
6cc30c3e-594f-4282-93ff-a5c3813efa5c	6ac99d21-6d61-4c1b-9bc3-8f222cfd44f3	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	\N
bb42aa53-6e74-4249-8bde-bf34a5f9ee91	c1bd6aa5-4b8c-4905-ab85-d0f6116c26d2	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	\N
cdbbf644-4ca5-40ef-9a05-b52cd523a1c9	aabdd124-5231-4e59-9662-5eabcbb12a35	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	\N
8599c47a-e0ca-4d2f-8640-af360c471550	391c5fe3-1d1e-4faa-951a-53d408672097	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	\N
897032c4-8978-4829-9e26-acc0b56c8729	da82ec7c-c33d-42ef-9e7c-11407ad56658	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	\N
2397bd18-1b1d-4675-9e85-4230ee1c7b58	67c580fc-477a-4f1d-aedc-64f40fe57801	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	\N
391d317a-5b4a-464d-bda0-4a747965e274	576af804-e9d9-4a8e-96ae-b38b32ab78f2	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	\N
be356b3a-ef38-49c0-86ef-c17de8a12f0b	8945b8b2-4342-42f7-b118-0f86ab8be729	70168e01-9714-46d8-83d1-33cd0e653fe3	9a8b2b90-0864-42f0-8858-cf374b52438a	Set of 5 Macarons	Default · Set of 5 Macarons	2	185000.00	\N	370000.00	\N
9dd7110b-5888-4b24-bcdf-ab694bc4d7b4	4477228e-355c-44c3-aa66-006060651356	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"note": "Ribbon v�ng, kh�ng sprinkles", "textOnCake": "Ch�c m?ng sinh nh?t An!", "candleCount": 7, "referenceImageUrl": "https://example.com/ref.jpg"}
414fc7ba-8e6c-4507-8078-dae188bd025a	d1711b85-ffa7-471c-82fa-a2fc8e7d8257	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	null
553686b8-28f7-4c28-bf62-0772a2bfcbe0	1fac125a-c877-4b7c-9df5-c38a5baf89d7	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	null
464f4b51-b852-401d-a26c-a827d950f301	4ce0cf06-7d6f-4da4-b7b3-f50a995f0e81	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"note": "Ribbon vang", "textOnCake": "Chuc mung sinh nhat An", "candleCount": 7, "referenceImageUrl": "https://example.com/ref.jpg"}
a0098b7d-bf08-4b40-ac37-4a22c07fe979	d54352b3-9021-484c-922a-8e60b62e1717	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
e491f3b4-732d-4032-bbd2-c1f21d533013	b2c8b6ee-c6b4-48cd-872d-44c0ee099b2a	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	null
7016ddc3-9641-4db1-aca8-98b555b6d1be	9b591661-d213-463a-98d0-d01960d09ba8	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	null
52a82980-055f-4835-b620-7849b4db681c	6839cfd4-2d2b-4d11-81e9-dff17295ec0c	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"note": "Ribbon vang", "textOnCake": "Chuc mung sinh nhat An", "candleCount": 7, "referenceImageUrl": "https://example.com/ref.jpg"}
81c511ce-56aa-46c0-93da-c04ae1f6fddf	1b4901e5-9a3d-4c2c-a66a-19395b5f3eb7	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
321a4495-7cb3-4031-87ac-e9088baa82aa	1613cc7c-ebbb-4ce0-8d04-b487547caef2	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	null
6e523843-be2c-49ac-a7e9-0531b8185771	e03a6eae-b28f-40b4-a2e6-ea43077690e4	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	null
b9ff8e41-fd90-4842-91e1-3d920fb7cdec	d09490bc-4a8a-4e90-bca2-2993b580cd02	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	null
04a83cfd-309c-476d-a27a-59bb1627f8c5	99e18f60-be97-4690-b088-46e2d4df8f46	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	null
099a9db6-b0f5-450d-8aba-fb603ffed94a	c8de4f77-6501-467f-a7c5-a70cbc551d40	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"note": "Ribbon vang, khong sprinkles", "textOnCake": "Chuc mung sinh nhat An", "candleCount": 7}
be4d2763-7f70-4514-8adc-5f0b859f5918	2c8c866b-ba60-4941-985f-25d5fc8e4080	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
2ce16007-7418-42b7-84aa-2525b2120ba4	2b6d0ea0-e8a9-45a7-815b-19d89c8ecacd	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"note": "Ribbon vang, khong sprinkles", "textOnCake": "Chuc mung sinh nhat An", "candleCount": 7}
22748f6b-d4cd-43a9-8d38-4dd6c95cdba4	54d39164-20eb-4ee8-bfed-9308c4ac5c6d	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
421f73d5-a2b4-40e2-a834-92f515892384	1f62576c-5b36-433b-816a-54ed7730a30d	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	null
7fad6ef1-2bec-42dd-8f7f-bbc8b348d054	0d216cb1-a7fe-43ed-b2c1-a03a6d465eb5	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	null
86ad996e-8d69-4533-8de6-5003ad87ad84	f1c3e99c-31d6-4973-be27-21ef727fc522	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"note": "Ribbon vang, khong sprinkles", "textOnCake": "Chuc mung sinh nhat An", "candleCount": 7}
7affe134-ef42-4ced-a7ca-035420d6df51	50f3345d-7363-4dd7-98e3-1544baa8b598	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
00daa5a1-c399-4d14-9f14-d1bb11bf0bfc	f0c33315-a5c8-4b7c-a086-c9e828ceaa19	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
c1e0f709-dd24-45b4-8b18-8de6cc315b18	e387ebf2-adc9-4618-91d8-5daaab86e242	70168e01-9714-46d8-83d1-33cd0e653fe3	9a8b2b90-0864-42f0-8858-cf374b52438a	Set of 5 Macarons	Default · Set of 5 Macarons	1	185000.00	\N	185000.00	{"flavors": {"Lemon": 2, "Jasmine": 3}}
af741f46-235f-4e9f-8607-47eb04cb5d9f	850899fc-8c0d-42ea-bb52-1e805cf6fb1b	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	null
af375cb3-fa11-416d-9fea-46f7e2125be5	caf835e3-6fff-4edd-96d7-f90025c415b0	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"note": "Ribbon vang", "textOnCake": "Chuc mung sinh nhat An", "candleCount": 7}
ae824fba-dd0d-41bf-bdfd-29e065d0e101	be91f242-979e-4a53-b593-8d7f20bd243c	70168e01-9714-46d8-83d1-33cd0e653fe3	9a8b2b90-0864-42f0-8858-cf374b52438a	Set of 5 Macarons	Default · Set of 5 Macarons	1	185000.00	\N	185000.00	{"flavors": {"Lemon": 2, "Jasmine": 2, "Earl Grey": 1}}
d478f76c-a8fb-47ad-9740-b454f9e74c43	08c983fd-7a1d-4a55-9f10-ca8cb03d231f	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
8ae53e08-dfe2-47e9-bd8f-760c416205ec	08c983fd-7a1d-4a55-9f10-ca8cb03d231f	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	null
1e1df0d9-7830-442a-b3cf-cd44b83fa11d	59137e9e-e71c-4fe7-80e1-2c071b3ac15e	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
ea6dbbee-f0d2-4336-8936-e0edeff0aa4d	fb138522-366c-42f5-a37b-6468cfc2b21a	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
f6cf465b-6405-4f32-bb33-0a6d3fb17c3a	94d6b88e-0960-442f-b479-fd1737296478	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
13dbc1a2-0103-4d8e-be52-b327af1376b5	f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
380f0022-4409-49cc-8abe-e3782430417e	97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"textOnCake": "Happy", "candleCount": 3}
31c860ac-07b6-4113-85a7-6c8af421e679	3dfa2152-e081-405f-af1c-01cf28f36833	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
1e42bfd7-48b4-4b98-8501-e1d8b5604432	333f3385-3ef1-468a-b268-0d58e4b8d4d5	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
f0c2241a-e6c7-4ca7-ae26-b8f4b15d4a1e	914b19c3-d8ad-46fe-a486-7ca8365ec2b7	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
676d7dff-19d2-44a2-b070-b67b33b79b5c	4b2619c3-53b2-4070-9d2d-40493747d077	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
3e99b6b1-ed5c-4279-8ffb-e14a49fb57ac	e700e920-338a-4b4c-be66-35653f8d8302	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
c682a0dd-83ee-4afe-88f8-d0d5fae4901f	32dcda4c-0995-4645-a367-a97d7d9a9be3	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	null
c07c5a02-3e82-4f95-8d60-bc3f000a44f3	cfd9e126-956f-4032-847b-8593ece91985	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"note": "Ribbon vang", "textOnCake": "Chuc mung sinh nhat An", "candleCount": 7}
21cf7934-55b0-496c-81bd-429334112de7	5cc96b01-2502-445c-afd4-34c05f6196b6	70168e01-9714-46d8-83d1-33cd0e653fe3	9a8b2b90-0864-42f0-8858-cf374b52438a	Set of 5 Macarons	Default · Set of 5 Macarons	1	185000.00	\N	185000.00	{"flavors": {"Lemon": 2, "Jasmine": 2, "Earl Grey": 1}}
47cfb771-44a3-40cb-9290-0a290ac8beae	02ff0412-d0f6-4619-8263-c6c4b4d4b6a1	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
5733c52f-f111-444c-b77a-5ed83bb5d2fa	02ff0412-d0f6-4619-8263-c6c4b4d4b6a1	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	null
279e3565-3fd6-4888-a524-8b8463d7254e	ae1b56a6-baef-45fc-bdcc-b66841201677	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
5fdb1fe9-52ac-40be-8c82-2a0e1cb4fd0d	2cc97ad0-2af0-4b4b-9bea-94e4383e4628	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
da8b83fe-0014-407c-9d8e-429f31890fcf	79696db8-7e3d-4408-89aa-d5010de88388	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
53be70b9-0735-44a2-a4fe-65ffffb25bff	ef97c0c0-67be-4cce-aa98-efa1aa3a74bc	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
b5818452-715c-436b-8259-cf1b158655ae	22cb5aaf-7cd9-4483-8232-0209b84636b6	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"textOnCake": "Happy", "candleCount": 3}
374a15ff-48f8-4fe8-b097-521f5149106e	05c829ec-c0fd-41b1-9c05-102bd43439a6	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
223d60c9-bd70-4711-9107-8e053d545eb6	031479dc-1160-471b-a16f-cce9ff1625f6	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
2bdd026e-d0d1-4f75-ae85-f7e3a7694ef4	d65f2099-6c4d-456c-8dc2-87d357842f4c	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
2871a287-c3c9-41bb-85fe-b9e49ac8fd96	a3236cb6-463b-4402-8bc7-fcbd666257d6	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
55d6f6a3-4657-4807-ba84-5a5990427401	f5158425-e1b1-48a9-bca8-8e4bf4fa337d	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
121fb3b3-0722-4492-be0c-f52832d596b4	a70eece6-5748-4365-a6ab-990aaf2249cf	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
9ba9f1ea-725e-4bb1-9c9e-2acf4d968db0	67f14c8a-c137-4a45-974c-45ab1df77460	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	null
e4ed7953-a995-4f52-9eeb-2d107a91fb82	671dcde8-bf46-4361-9302-38ba388c2577	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	null
9cf8a72f-75af-435d-a118-73e0673247ca	175701bc-0450-4429-96d5-735e9aafcb82	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
203811a6-b94e-478c-b8ed-3cc629ebdaff	2e5538cf-93fc-4590-9858-68d6fe7e5fd6	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
dbefc027-2f4e-4fb8-891f-68159226a349	94e2d801-4952-476a-83d2-b0ff9d87de66	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	2	60000.00	\N	120000.00	null
eb4af26c-5d0b-4ed1-b429-ae27e47e78fe	4f927fab-084c-4a89-99d0-079e924b8819	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"note": "Ribbon vang", "textOnCake": "Chuc mung sinh nhat An", "candleCount": 7}
4b138648-35bb-4cfb-9289-5714f367d8e6	d411c7d5-fcac-48eb-9f26-3df9366f17be	70168e01-9714-46d8-83d1-33cd0e653fe3	9a8b2b90-0864-42f0-8858-cf374b52438a	Set of 5 Macarons	Default · Set of 5 Macarons	1	185000.00	\N	185000.00	{"flavors": {"Lemon": 2, "Jasmine": 2, "Earl Grey": 1}}
10e4ed45-ed81-43e3-8a86-9acb541bfcf7	21417b81-1fe7-461d-b3ac-6bd595328a35	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
03a7e695-dbb7-4ea1-9077-bbdb4cd4c2e9	21417b81-1fe7-461d-b3ac-6bd595328a35	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	null
47d7604e-ba8c-448f-8f29-70497a311537	d11bfa82-317d-4bf1-92ac-ae822d083dd8	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
cef2ad1b-0f7f-4550-84d6-faf40f37a603	6962c74f-4108-46dc-9f03-1d6db00a6751	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
0b39123e-fcc0-47c6-9720-3a5bb02d34a6	5066a015-de2b-4f75-acac-357c4ade16cd	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
96cbe157-507d-4877-b826-957a017354f6	c4b3e273-2560-4dab-ab8a-64c3afb68727	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
12054539-25ae-4052-9f72-fdd7dace4688	6a92f954-1fb8-4cbd-a9aa-7423dde45627	7e19226d-e44a-4e60-83d6-cd3f8459b2c6	7a4e2f31-0221-4c16-8d5e-d57f9c37c21a	Signature Strawberry Cake	16cm · Strawberry	1	778000.00	\N	778000.00	{"textOnCake": "Happy", "candleCount": 3}
033cfcd6-3970-4daa-8610-b39918d91789	4831b162-0d0d-40df-a1b9-5360d034f731	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
ebe938f7-156f-406b-94e9-42471a5d170f	932e0a80-ad20-4c57-87e1-45770d409aa7	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
86f19b30-a130-4c1c-ae89-dc444dd7a6d3	31e11ed9-a86d-4403-97f4-0ad0fda04556	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
b14cb785-9496-482e-b281-8bf531ab3dcf	7b4a9ff3-9a49-4b5d-84ac-8ce47f65a291	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
0721100f-d2ff-4a87-9f2d-567e086eaeb3	cf3c0c8e-40aa-4025-9580-b4c941f82ece	dc1220fa-88e4-45ad-a649-d54c2f9b6c75	b005e2c2-2fd0-428b-b5e0-38d21c0400f4	Original Cookie Choux	Default · Original Cookie Choux	1	60000.00	\N	60000.00	null
\.


ALTER TABLE public."OrderItem" ENABLE TRIGGER ALL;

--
-- Data for Name: OrderStatusEvent; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."OrderStatusEvent" DISABLE TRIGGER ALL;

COPY public."OrderStatusEvent" (id, "orderId", "fromStatus", "toStatus", "actorId", note, "createdAt") FROM stdin;
9e142cdb-e95f-49c4-95ba-2fec0d2e2d4f	f0a0d840-5792-4d71-bb97-b1bfb80ed10d	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-10 09:25:28.332
0901a088-bfc8-4367-bade-63604dce83e5	f0a0d840-5792-4d71-bb97-b1bfb80ed10d	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-10 09:31:36.986
fd5c4ef4-65c1-4d1a-b5df-cd0a82b5de61	f0a0d840-5792-4d71-bb97-b1bfb80ed10d	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-10 09:31:38.626
a4f9a306-fae4-4c24-9de5-7994d2f26cb9	f0a0d840-5792-4d71-bb97-b1bfb80ed10d	IN_PREPARATION	READY_FOR_PICKUP	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-10 09:31:40.025
25be1a79-b888-46c3-ab3f-271e4dda1fef	f0a0d840-5792-4d71-bb97-b1bfb80ed10d	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-10 09:31:41.338
f1dc5bcd-d27d-412b-b3c4-254572719bf4	bda681ec-e669-4029-b6f6-31f823328307	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-10 09:56:42.836
c87d524f-5f1c-4db5-8a66-553b243acb82	bda681ec-e669-4029-b6f6-31f823328307	PENDING	CANCELLED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-10 09:57:08.655
2650109e-2747-4c4f-88ce-28d2b4493310	89fab936-1cc9-4b40-b4c5-be0c4b54109f	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-10 09:57:46.339
4df066b4-35e6-4e06-bbc1-fa3501fc242b	89fab936-1cc9-4b40-b4c5-be0c4b54109f	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-10 09:57:51.514
214c0763-9280-4c18-abac-f7254f82bcfa	89fab936-1cc9-4b40-b4c5-be0c4b54109f	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-10 09:57:54.199
cdf9205a-9ade-4527-bfe4-68fdde37072f	89fab936-1cc9-4b40-b4c5-be0c4b54109f	IN_PREPARATION	CANCELLED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-10 09:57:55.877
002250be-2e8a-4961-bb68-7e4de2ba5502	c2a3e00d-5319-4144-84b4-eff3d58b0659	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-11 10:46:38.467
efe67771-7d1c-4b26-a8c5-69647f576c4e	d8789680-e784-4186-8c35-27863524ca68	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-11 10:49:59.32
a49110a7-8664-4cfe-8feb-f32185957d9f	048a1b04-4f67-4b24-9056-5fa16c1d0b0f	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-11 10:51:09.58
28761ab9-f119-4495-9f06-831c26af61db	81d4c479-c7be-46fd-8181-6dc4616541bb	\N	PENDING	3293c2bf-4ceb-4e45-8597-61bad26a4bad	Order placed	2026-05-13 06:33:43.306
115ebdfb-20a4-4e12-af17-b56a2b2b8df6	0cf1fecb-9856-447c-8a88-3bd8adff8bc9	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-13 08:11:07.785
1b166599-5114-4668-9110-78fb1105f1c2	322fdd05-ee34-4cbe-8f99-e5eb37ed5314	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-13 08:11:23.656
a33908db-ab3e-487e-b620-a2ab181c7af4	322fdd05-ee34-4cbe-8f99-e5eb37ed5314	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-13 08:13:38.947
b9e1ceca-eeb2-46d3-9d35-5d3479d7f1d0	322fdd05-ee34-4cbe-8f99-e5eb37ed5314	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-13 08:13:44.222
01b1ae59-df3c-4a80-a3b3-c169cf781716	322fdd05-ee34-4cbe-8f99-e5eb37ed5314	IN_PREPARATION	READY_FOR_PICKUP	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-13 08:13:48.013
a81a6ada-3639-44cd-a0d7-da3f26e9ce76	2e5da661-e48b-4e68-b7cd-5b5397bc3d54	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-13 08:14:42.681
be87f7d8-2b42-46f4-b2be-e3b60fca8c91	0cf1fecb-9856-447c-8a88-3bd8adff8bc9	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-13 08:14:54.099
27957427-ea64-401a-92e4-a709592d7c3b	0cf1fecb-9856-447c-8a88-3bd8adff8bc9	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	Transferred to central kitchen	2026-05-13 08:15:04.13
f1a05d51-d587-43b0-8c20-80876233a607	0cf1fecb-9856-447c-8a88-3bd8adff8bc9	SENT_TO_KITCHEN	READY_FOR_PICKUP	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-05-13 08:15:34.529
2eb0fccc-8eb1-41df-8da7-f38384b5673d	0cf1fecb-9856-447c-8a88-3bd8adff8bc9	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-13 08:16:12.515
ed3b607c-6dce-42f3-b6cc-70080c55f3cd	322fdd05-ee34-4cbe-8f99-e5eb37ed5314	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-13 09:35:54.652
547ecf42-830a-4902-b4ed-b6c87234a689	81d4c479-c7be-46fd-8181-6dc4616541bb	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-13 09:36:01.98
a2c3cfc9-d905-4d56-95ee-1a2135adc212	2d79c95b-ce16-459d-91cf-53d1f39edc4a	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-13 09:57:47.535
480a6e05-352f-4fd8-bad3-86f9166786a3	2d79c95b-ce16-459d-91cf-53d1f39edc4a	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-13 09:58:14.173
09c7784c-3874-45f9-9c37-6d565d774903	2d79c95b-ce16-459d-91cf-53d1f39edc4a	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	Transferred to central kitchen	2026-05-13 09:58:15.526
9bbebab8-bda3-4e42-99b8-ece1c54ceed8	2d79c95b-ce16-459d-91cf-53d1f39edc4a	SENT_TO_KITCHEN	READY_FOR_PICKUP	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-05-13 09:59:30.145
1d1b79d6-f5f1-45eb-93fe-8c250beed0b4	cff6b826-0ffa-4458-96bb-ca30dd0e310b	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-13 10:23:58.049
02357f3c-b098-4692-9d87-5c1c77839b8a	36cb2b2b-f0e8-44b5-bc59-23931e320913	\N	PENDING	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	Order placed	2026-05-13 10:27:36.161
cc25948e-1ad9-4825-b70d-1cc024aac5e0	2d79c95b-ce16-459d-91cf-53d1f39edc4a	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-13 10:43:06.595
18d53c21-9479-40a4-b1e4-fcb4e8c245dc	36cb2b2b-f0e8-44b5-bc59-23931e320913	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-14 05:06:02.433
47de4bbf-3bee-4243-b627-bb1fa7636ef4	060470be-e651-4d99-b519-9ea5491effd9	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-14 05:07:49.74
d8df175a-3402-4a27-8a9d-1709f9d0b472	060470be-e651-4d99-b519-9ea5491effd9	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-14 05:08:23.019
eeb8b39f-1145-4726-9683-5088d27c90d1	060470be-e651-4d99-b519-9ea5491effd9	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	Transferred to central kitchen	2026-05-14 05:08:24.399
4f76a94d-87d9-45fd-8b54-44c080c42b9d	060470be-e651-4d99-b519-9ea5491effd9	SENT_TO_KITCHEN	READY_FOR_PICKUP	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-05-14 05:08:53.925
a3f8b8b2-6f7c-48c9-8da6-79f7737820af	060470be-e651-4d99-b519-9ea5491effd9	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-14 05:09:19.688
72b4edb7-e8ed-41d8-a2aa-d6942598d83c	c47b501f-763d-4a2d-bf4b-2377d8c39b6f	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-15 10:51:49.31
083a80cb-8c10-4e4c-90f0-77670e9edfc1	c47b501f-763d-4a2d-bf4b-2377d8c39b6f	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 10:51:59.873
25495016-a03d-45b2-9337-faffdf8a5155	c47b501f-763d-4a2d-bf4b-2377d8c39b6f	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 10:52:01.487
f0de4c2f-8baa-4a16-ba8d-05084bae5de6	c47b501f-763d-4a2d-bf4b-2377d8c39b6f	IN_PREPARATION	READY_FOR_PICKUP	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 10:52:03.305
f7f03200-b980-4725-b6e2-8ffd1b6c4990	c47b501f-763d-4a2d-bf4b-2377d8c39b6f	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 10:52:04.222
dfc4b2d3-5d39-434a-be70-5efbed7f9053	54081945-a072-4dc5-924c-60aa005a4344	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-15 10:56:12.951
ef33c5a2-a25d-4890-a2a0-75b99b2135b5	54081945-a072-4dc5-924c-60aa005a4344	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 10:56:24.76
ea03fe8d-53fb-4b70-8771-f4be4d3e8150	54081945-a072-4dc5-924c-60aa005a4344	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 10:56:26.012
cd7b8076-a979-4e12-85fa-0455b63f8c6a	54081945-a072-4dc5-924c-60aa005a4344	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 10:56:27.376
904d1c23-b561-4142-9fd5-fe10f973c415	a2476e33-44d3-4c2b-ad4d-798099f6522c	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 11:01:08.616
44474497-7f40-4d06-8ea9-d54f9eac962d	54081945-a072-4dc5-924c-60aa005a4344	IN_PREPARATION	READY_FOR_PICKUP	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 10:56:26.669
04553280-ebdb-451d-b664-4d751b1fbe74	a2476e33-44d3-4c2b-ad4d-798099f6522c	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-15 11:00:51.786
a036f36a-66af-4db2-97f7-9c0b211ba5c3	a2476e33-44d3-4c2b-ad4d-798099f6522c	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 11:01:29.86
96bc6329-f0f5-4f3c-8ef5-7a8bd09544c6	a2476e33-44d3-4c2b-ad4d-798099f6522c	IN_PREPARATION	READY_FOR_PICKUP	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 11:01:30.528
e8096a3d-1e7f-4b0d-90c1-004d83ae8a2d	a2476e33-44d3-4c2b-ad4d-798099f6522c	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-15 11:01:31.156
85ff362c-57e7-4399-b8dc-a1a46af1381a	7da53799-e88f-459c-b0ec-c988e7d8793a	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 04:45:33.348
187c6cc0-0b51-4a78-ac20-a18d0afb96fc	0a6067cb-cfb2-4be0-b5c7-4d98fe27129e	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 04:45:34.22
595cb312-a4c1-443e-a8ef-99db09d3cf5b	c573a2c0-ab99-4fe5-a4fb-6807a578688c	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 04:45:35.06
2a967643-e603-4d52-b95a-2dd5fa9a3a51	71fa0429-dd11-429a-8d10-6444d48180df	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 04:45:36.128
1d3b9b8d-dd01-42ac-a169-9468afa228e7	1e848d09-56e4-4f97-892a-491cbed7c625	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 04:45:37.144
44aecf94-d700-482c-9ce3-4f91cd3683d0	06d2dfdf-83cb-4485-95f4-e83287e72c6f	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 06:23:28.109
b69c09e9-3200-452f-8278-2271371cd411	8b0aaca7-6e78-4010-b988-cc241b9f0e34	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 06:23:29.036
96dfe7e8-f2ef-45ef-8fbe-89ef69131e9b	3c3a9c52-ccfd-4669-ae34-b8c1ab660813	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 06:23:30.033
3dcf5980-ef77-4934-b2c1-f33e394724e0	ea013a43-7376-4e96-aaa1-04eee039bf28	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 06:23:31.183
df6a8726-49c3-4f21-b35f-e2241d71bc6d	7fd35beb-5d8a-4f76-b6f8-125abe027dc2	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 06:23:32.157
33864926-6558-410d-8e51-3dbd3fd92e03	360b1f6b-906b-49db-b7e3-67541b684874	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 06:23:57.573
aa753e1f-bba8-444c-9f8b-b664855a496d	f4221321-a57b-4002-a94f-0d93688d71c1	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 06:23:58.403
3cb5a5cb-73ce-4963-aa02-c0f8c24306cc	71e6adfe-e78e-454c-adb3-bee43493df48	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 06:23:59.272
0d7ad392-f70c-4ae8-a14a-68c5e170087c	415d8f50-24cc-47ad-a356-e65c5a126a36	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 06:24:00.257
4f8bc991-34dc-41b5-a122-ffbf1a3477f7	930a41c4-0cd0-44a3-80d0-f1dec0a7987d	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 06:24:01.174
05f7b6ea-704f-49b9-a9c4-cc3217b940c2	f416ccc5-c756-4486-a4f6-21000213936e	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-27 07:07:05.829
4e848f48-9526-4ed7-877e-9b7b0164773a	6ac99d21-6d61-4c1b-9bc3-8f222cfd44f3	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 10:33:52.977
9742c826-8cc6-4fd5-9fad-761ac79c1173	c1bd6aa5-4b8c-4905-ab85-d0f6116c26d2	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 10:36:25.565
29ca9c1d-5adf-4fb6-abd9-309e975281e3	aabdd124-5231-4e59-9662-5eabcbb12a35	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 10:36:26.491
c1c4b83f-2826-4f9a-b800-9557fe403a1c	391c5fe3-1d1e-4faa-951a-53d408672097	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 12:55:06.331
9f72e19a-46d0-46d1-908f-7d5b8f2708d8	da82ec7c-c33d-42ef-9e7c-11407ad56658	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 12:55:07.371
27774e8f-71bd-40fc-9487-dd9abbf2077b	67c580fc-477a-4f1d-aedc-64f40fe57801	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 12:55:47.123
f8147919-7ff3-48e5-9103-ff6f93f83288	576af804-e9d9-4a8e-96ae-b38b32ab78f2	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 12:55:47.93
b57de5ac-fd6e-4538-8fab-c8c2fdc88d1d	8945b8b2-4342-42f7-b118-0f86ab8be729	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 12:56:11.038
54df29a9-7575-4131-adbc-2354ac6fb97e	4477228e-355c-44c3-aa66-006060651356	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:42:40.802
2586d802-1236-4179-9c97-4e06379aedd0	d1711b85-ffa7-471c-82fa-a2fc8e7d8257	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:45:05.536
e4f52fb1-6b34-40ae-b1a4-a647d6496212	1fac125a-c877-4b7c-9df5-c38a5baf89d7	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:45:06.445
f9d040be-b508-4950-b44b-75a228392789	4ce0cf06-7d6f-4da4-b7b3-f50a995f0e81	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:45:13.734
0d8b57fc-27ba-4019-995f-e3d43e851294	d54352b3-9021-484c-922a-8e60b62e1717	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:45:14.025
e8a906f3-f7a4-4e85-b5a8-b965a390d24b	b2c8b6ee-c6b4-48cd-872d-44c0ee099b2a	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:45:46.219
4f438926-b658-48f7-b22b-ff23d40aa0b3	9b591661-d213-463a-98d0-d01960d09ba8	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:45:47.087
47de9764-7a1c-4845-a7ef-595215025fa9	6839cfd4-2d2b-4d11-81e9-dff17295ec0c	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:45:54.016
5de7c1c7-1c01-449b-a46b-43225b9d5c2a	1b4901e5-9a3d-4c2c-a66a-19395b5f3eb7	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:45:54.364
44ddd018-af4c-4af3-9388-737fa9949f02	1613cc7c-ebbb-4ce0-8d04-b487547caef2	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:51:09.78
5e5786e5-1914-49c0-898d-9a152b3868ca	e03a6eae-b28f-40b4-a2e6-ea43077690e4	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:51:10.718
46ccd531-fd5a-4e46-bb4f-9e62c64f83f3	d09490bc-4a8a-4e90-bca2-2993b580cd02	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:51:15.909
a25742dd-8af1-469b-99d4-eaaaad22a18c	99e18f60-be97-4690-b088-46e2d4df8f46	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:51:17.029
27272ec0-3899-4e6a-8e8a-5f8b5a91dd95	c8de4f77-6501-467f-a7c5-a70cbc551d40	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:51:19.817
1c80ff0f-040a-4a19-b129-321c7f1c3591	2c8c866b-ba60-4941-985f-25d5fc8e4080	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:51:20.249
88156171-5074-42e7-a60f-736116966bee	2b6d0ea0-e8a9-45a7-815b-19d89c8ecacd	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:51:25.892
8ba55612-fe21-4fda-a349-9e64b4388de7	54d39164-20eb-4ee8-bfed-9308c4ac5c6d	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 13:51:26.166
5870b3f7-f661-49d6-872c-4dae7cb7469f	1f62576c-5b36-433b-816a-54ed7730a30d	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 14:56:52.79
727c29e4-f833-493c-8c70-d2c1a589ff37	0d216cb1-a7fe-43ed-b2c1-a03a6d465eb5	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 14:56:53.812
a19f7733-1fe3-4345-aafc-238c550a1139	f1c3e99c-31d6-4973-be27-21ef727fc522	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 14:57:01.145
48464725-efd9-46fe-a1c6-93f21f12af65	50f3345d-7363-4dd7-98e3-1544baa8b598	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 14:57:01.452
ac7eb5fc-7324-4da6-89bd-839714ccb93a	f0c33315-a5c8-4b7c-a086-c9e828ceaa19	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-28 18:31:25.714
267004a0-676b-4752-8e84-cfba51db248b	f0c33315-a5c8-4b7c-a086-c9e828ceaa19	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-28 18:31:26.208
39c38656-5b7f-4f56-b5bc-fc8ba800567e	f0c33315-a5c8-4b7c-a086-c9e828ceaa19	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-28 18:31:26.382
656e473a-af5a-48e0-a108-5cd2ea979a82	f0c33315-a5c8-4b7c-a086-c9e828ceaa19	IN_PREPARATION	READY_FOR_PICKUP	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-28 18:31:26.545
f2315212-6b38-4773-be79-85aad274b093	f0c33315-a5c8-4b7c-a086-c9e828ceaa19	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-28 18:31:26.714
72358ce2-b7f3-4e13-b182-b4b226c8108f	e387ebf2-adc9-4618-91d8-5daaab86e242	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 06:54:13.889
86738f3f-6210-40e9-b0c7-57ae69d2830d	850899fc-8c0d-42ea-bb52-1e805cf6fb1b	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:17.382
43ad1939-73d7-4055-b193-7a406eb0e2df	caf835e3-6fff-4edd-96d7-f90025c415b0	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:17.637
56357c4b-1d3b-46c1-b517-627d7718e319	be91f242-979e-4a53-b593-8d7f20bd243c	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:17.925
0d3954b3-7a5b-44ce-95f5-e978befb71c0	08c983fd-7a1d-4a55-9f10-ca8cb03d231f	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:18.44
7835308e-0c65-404a-9280-33b2250e54e9	59137e9e-e71c-4fe7-80e1-2c071b3ac15e	\N	PENDING	61f1af85-9347-49d4-86a3-cb858d5a0b69	Order placed	2026-05-29 08:01:19.415
cccf9223-a9d1-4cd5-9098-f1550a6f3965	fb138522-366c-42f5-a37b-6468cfc2b21a	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:19.645
98545a03-4261-46e2-8d34-3b87ef193b45	94d6b88e-0960-442f-b479-fd1737296478	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:20.269
0fc7cb50-cd5c-4a21-8e37-166d5a092709	94d6b88e-0960-442f-b479-fd1737296478	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:20.75
6dbb430f-52d7-4ce2-97a0-1d9497f54c36	94d6b88e-0960-442f-b479-fd1737296478	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:20.98
d020d9ea-b3f0-4d06-bdb5-617db58f2ebd	94d6b88e-0960-442f-b479-fd1737296478	IN_PREPARATION	READY_FOR_PICKUP	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:21.178
b936f622-ab27-4a52-be18-656a8a5d11ed	94d6b88e-0960-442f-b479-fd1737296478	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:21.418
3247d997-840a-40f1-8286-380b9f570a7d	f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:21.704
cc0e0b73-6098-4712-a7c0-1089c2e57b53	f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:22.134
1c12e169-d3dc-4225-9b1d-ebbd9dec7f7b	f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:22.338
a72b72b6-55d1-4382-a871-bf8f8eefebfe	f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c	IN_PREPARATION	DELIVERING	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:22.541
a6413d94-5349-4015-950a-76f81e6c180d	f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c	DELIVERING	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:22.77
53200f54-1643-4122-867c-83bb3a682ea3	97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:23.002
1a5b6dfd-6c20-4bd2-8fe0-1f938128021b	97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:23.445
71d43423-adef-4553-a37d-0bc68a99594e	97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	selftest	2026-05-29 08:01:23.674
2e16e5c6-0713-4be4-8016-26100186c1a2	97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2	SENT_TO_KITCHEN	READY_FOR_PICKUP	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-05-29 08:01:24.742
30da2f68-bf8a-482b-bc0f-9cfbdce90403	97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:24.936
ebc3b0a0-6d3f-4ed2-902d-ace60e451968	3dfa2152-e081-405f-af1c-01cf28f36833	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:25.209
0b3bdb0e-f3d7-4618-b96e-fae907157413	3dfa2152-e081-405f-af1c-01cf28f36833	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:25.648
38571f17-9af0-43ee-9a1a-2762eed770a3	3dfa2152-e081-405f-af1c-01cf28f36833	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	Transferred to central kitchen	2026-05-29 08:01:25.798
2eb373a4-1264-4a8b-b3d4-42fdfed2d28a	3dfa2152-e081-405f-af1c-01cf28f36833	SENT_TO_KITCHEN	DELIVERING	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-05-29 08:01:26.267
72967725-44b8-46db-b784-3348e5f3baed	3dfa2152-e081-405f-af1c-01cf28f36833	DELIVERING	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:26.479
bea0198f-93a6-4039-82b8-b6f34e05cca6	333f3385-3ef1-468a-b268-0d58e4b8d4d5	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:26.761
e15c826f-1b05-448e-8dd7-bcbd020fe45a	333f3385-3ef1-468a-b268-0d58e4b8d4d5	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:27.115
4b99a91e-f7f8-4396-8de5-ca142dec9ada	333f3385-3ef1-468a-b268-0d58e4b8d4d5	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	Transferred to central kitchen	2026-05-29 08:01:27.28
e333bfb7-8148-43a3-af20-7023537814e9	914b19c3-d8ad-46fe-a486-7ca8365ec2b7	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:27.495
295d61d8-0d6c-43ee-b8b9-6231d4ce3eef	914b19c3-d8ad-46fe-a486-7ca8365ec2b7	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-05-29 08:01:28.057
95151624-51a6-495a-b229-def3ed08740a	4b2619c3-53b2-4070-9d2d-40493747d077	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:01:28.396
0109f6b9-b6c9-46df-8c6b-3fad5cbfeac6	e700e920-338a-4b4c-be66-35653f8d8302	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-05-29 08:02:41.811
f2d9a126-79b6-4ef2-b6f1-7f0bb1ca90fa	32dcda4c-0995-4645-a367-a97d7d9a9be3	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:31.079
b675e9d3-ec70-4219-a3d7-108ff365d66a	cfd9e126-956f-4032-847b-8593ece91985	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:31.547
7b22d282-76c2-41ae-a8d8-9cb0da018165	5cc96b01-2502-445c-afd4-34c05f6196b6	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:31.959
f5ab4d2b-6d83-4ac3-98ec-c0867737b967	02ff0412-d0f6-4619-8263-c6c4b4d4b6a1	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:32.663
154c8d58-5349-494a-80a5-7cd5d539c32c	ae1b56a6-baef-45fc-bdcc-b66841201677	\N	PENDING	d70495ff-161a-4f2b-a817-540ca2658367	Order placed	2026-06-02 08:57:34.184
837b0325-83aa-4044-bb63-819bbfb1239d	2cc97ad0-2af0-4b4b-9bea-94e4383e4628	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:34.573
2e85124f-307a-41a7-86c3-afbd60bd5eab	79696db8-7e3d-4408-89aa-d5010de88388	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:35.289
2092e11a-3201-45a8-a443-a462e842ad57	79696db8-7e3d-4408-89aa-d5010de88388	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:36.026
a6d20f4e-2025-42f6-b9f2-32d3ec4d03be	79696db8-7e3d-4408-89aa-d5010de88388	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:36.292
3ae5dcde-d7a7-49e1-9bdf-3d7148197b19	79696db8-7e3d-4408-89aa-d5010de88388	IN_PREPARATION	READY_FOR_PICKUP	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:36.537
efecdc69-c386-46fd-92de-703372dc9d45	79696db8-7e3d-4408-89aa-d5010de88388	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:36.739
d19bc807-d39e-4b44-b778-bd0d628b9bd8	ef97c0c0-67be-4cce-aa98-efa1aa3a74bc	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:37.069
65e97a3d-d525-41a9-9661-c3e40e10c91f	ef97c0c0-67be-4cce-aa98-efa1aa3a74bc	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:37.52
fe9a86e2-0dfc-4211-aa8b-c32df967e233	ef97c0c0-67be-4cce-aa98-efa1aa3a74bc	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:37.774
45b90ad1-3b97-4f06-a775-3d7832d1cdd3	ef97c0c0-67be-4cce-aa98-efa1aa3a74bc	IN_PREPARATION	DELIVERING	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:38.008
ec5434d8-8176-4587-b6ab-ec3b7aa860a2	ef97c0c0-67be-4cce-aa98-efa1aa3a74bc	DELIVERING	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:38.264
5ff3aaac-4a79-4257-81dd-a627ebd6b9d0	22cb5aaf-7cd9-4483-8232-0209b84636b6	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:38.549
b639b1e0-598d-4648-9f51-614e897228a3	22cb5aaf-7cd9-4483-8232-0209b84636b6	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:38.983
8c6731fa-8148-4989-96f2-2a1f9024ff26	22cb5aaf-7cd9-4483-8232-0209b84636b6	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	selftest	2026-06-02 08:57:39.224
a60a2cdb-c764-4da1-aab9-891865464b3f	22cb5aaf-7cd9-4483-8232-0209b84636b6	SENT_TO_KITCHEN	READY_FOR_PICKUP	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-06-02 08:57:40.651
b7eac683-7697-44a5-8ca1-9679368a0d9a	22cb5aaf-7cd9-4483-8232-0209b84636b6	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:40.875
989259ca-b0d3-4d69-88c4-994228f8ed38	05c829ec-c0fd-41b1-9c05-102bd43439a6	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:41.147
339055ef-169d-49b7-a353-bb052fb3f0b6	05c829ec-c0fd-41b1-9c05-102bd43439a6	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:41.67
79910b7b-c1b4-4d52-aa55-454fc0adfc69	05c829ec-c0fd-41b1-9c05-102bd43439a6	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	Transferred to central kitchen	2026-06-02 08:57:41.818
3212fe54-cdc9-49d4-99a2-327db443ebf0	05c829ec-c0fd-41b1-9c05-102bd43439a6	SENT_TO_KITCHEN	DELIVERING	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-06-02 08:57:42.255
5ede8132-26f2-4215-b1e0-d0daae2bd08c	05c829ec-c0fd-41b1-9c05-102bd43439a6	DELIVERING	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:42.498
558cb466-cdac-46b4-ac37-bde5fad4fef9	031479dc-1160-471b-a16f-cce9ff1625f6	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:42.826
adcaca24-b445-42b2-bf82-ffedbdfa6d5a	031479dc-1160-471b-a16f-cce9ff1625f6	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 08:57:43.159
642b3a5e-b94c-4c88-b53d-6fef99341969	031479dc-1160-471b-a16f-cce9ff1625f6	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	Transferred to central kitchen	2026-06-02 08:57:43.301
0971f3e1-1c74-4eba-8ad1-c433b5ecfa8b	d65f2099-6c4d-456c-8dc2-87d357842f4c	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:43.589
8c309e14-a74f-41fa-a59c-b3fd33a04745	d65f2099-6c4d-456c-8dc2-87d357842f4c	PENDING	CANCELLED	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Doi y	2026-06-02 08:57:43.885
d45cf898-2e52-4b5c-84be-dcc6a697a875	a3236cb6-463b-4402-8bc7-fcbd666257d6	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 08:57:44.306
6b2e9514-b310-40fe-aec8-4ebe4f10c801	a3236cb6-463b-4402-8bc7-fcbd666257d6	PENDING	CANCELLED	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	cleanup	2026-06-02 08:57:44.799
7581b05b-81d8-4a66-85b5-31a9b6db19ad	f5158425-e1b1-48a9-bca8-8e4bf4fa337d	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 10:34:27.088
4894dd6e-676a-45c7-9acc-14530f08e2a5	f5158425-e1b1-48a9-bca8-8e4bf4fa337d	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 10:34:27.374
6f918045-bab4-4d2d-8691-7a0d9187268c	a70eece6-5748-4365-a6ab-990aaf2249cf	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 10:54:09.796
c3808fcc-325c-4861-af17-653eefac6638	a70eece6-5748-4365-a6ab-990aaf2249cf	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-02 10:54:10.287
7ab1c325-b1c8-4043-bbff-9a15ddad74a1	a70eece6-5748-4365-a6ab-990aaf2249cf	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	Transferred to central kitchen	2026-06-02 10:54:10.431
59847fc9-3742-43d2-89ea-4622d6ff2811	333f3385-3ef1-468a-b268-0d58e4b8d4d5	SENT_TO_KITCHEN	READY_FOR_PICKUP	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-06-02 11:06:29.748
a28314cd-9879-4ebb-813c-83df262df76a	031479dc-1160-471b-a16f-cce9ff1625f6	SENT_TO_KITCHEN	READY_FOR_PICKUP	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-06-02 11:06:32.344
c8d1e993-2081-482e-9255-81f07c713adb	a70eece6-5748-4365-a6ab-990aaf2249cf	SENT_TO_KITCHEN	READY_FOR_PICKUP	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-06-02 11:06:33.311
cb48e2a7-9758-4c7a-931b-46048fac169d	67f14c8a-c137-4a45-974c-45ab1df77460	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 11:09:20.401
7decdd84-2b5e-47f0-a158-a5669a2a350f	671dcde8-bf46-4361-9302-38ba388c2577	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-02 11:09:20.588
fb42a1e6-e9a6-48e7-852a-315baebcebed	175701bc-0450-4429-96d5-735e9aafcb82	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:11:21.195
1a9c082a-4233-45f0-b416-a6d9f5b1dee5	2e5538cf-93fc-4590-9858-68d6fe7e5fd6	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:24:51.109
b55daec6-dd2f-45f7-8568-54b2b67a7386	94e2d801-4952-476a-83d2-b0ff9d87de66	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:15.773
ea90f132-e131-480e-8d59-3100752522ac	4f927fab-084c-4a89-99d0-079e924b8819	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:16.087
db401af5-f553-443e-89ec-826b3a126efe	d411c7d5-fcac-48eb-9f26-3df9366f17be	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:16.417
af5ad5b1-d2c8-4aec-a12f-2be844f0254b	21417b81-1fe7-461d-b3ac-6bd595328a35	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:17.001
80f7a907-7bbf-492f-b6f8-7d475bdd3c89	d11bfa82-317d-4bf1-92ac-ae822d083dd8	\N	PENDING	0502db59-3b85-40bc-9325-3556c61967c1	Order placed	2026-06-04 14:25:17.799
4dc40da7-4353-4ed7-9399-375d6c77f555	6962c74f-4108-46dc-9f03-1d6db00a6751	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:18.134
b2f3cc4d-f6c3-43cf-b16f-08221cf80595	5066a015-de2b-4f75-acac-357c4ade16cd	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:19.304
1e045ab2-b5fa-4feb-8b4e-a6ac2e3b1d5c	5066a015-de2b-4f75-acac-357c4ade16cd	IN_PREPARATION	READY_FOR_PICKUP	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:19.662
666815d7-7406-4ed3-ba8d-aaf1d08bf40f	c4b3e273-2560-4dab-ab8a-64c3afb68727	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:20.105
a31358ca-2ff7-4fc1-956f-0d0968c37f63	c4b3e273-2560-4dab-ab8a-64c3afb68727	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:20.758
f728d656-1da9-4d67-a564-d0a2d2d57910	c4b3e273-2560-4dab-ab8a-64c3afb68727	DELIVERING	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:21.138
215def76-101a-4b5a-afe4-5c97dc4349e4	6a92f954-1fb8-4cbd-a9aa-7423dde45627	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:21.73
ef39adc4-abb1-4189-8912-2d17e6345b9d	6a92f954-1fb8-4cbd-a9aa-7423dde45627	SENT_TO_KITCHEN	READY_FOR_PICKUP	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-06-04 14:25:23.035
da05dc23-ef88-4f84-a5c5-b319b7008d6f	6a92f954-1fb8-4cbd-a9aa-7423dde45627	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:23.256
75c57984-7929-41b7-a7a6-b5327ca6f566	4831b162-0d0d-40df-a1b9-5360d034f731	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:23.506
264bfa99-7ec5-4fd2-a60c-688d64715351	4831b162-0d0d-40df-a1b9-5360d034f731	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:23.947
c0f6b107-bf52-4e0b-8ee1-ce64641a8bb7	4831b162-0d0d-40df-a1b9-5360d034f731	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	Transferred to central kitchen	2026-06-04 14:25:24.089
dba71e20-a841-405c-9751-6b3811b1f88c	4831b162-0d0d-40df-a1b9-5360d034f731	SENT_TO_KITCHEN	DELIVERING	ab32baa0-382d-48e5-a542-b6f6a3620a9b	Dispatched from central kitchen	2026-06-04 14:25:24.496
9e58621f-f107-43fb-abdb-3a369d63a93d	4831b162-0d0d-40df-a1b9-5360d034f731	DELIVERING	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:24.691
6e916b6a-b2d4-4215-8e81-4833a79877a9	932e0a80-ad20-4c57-87e1-45770d409aa7	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:25.169
3807b5fe-e7f0-41ee-babb-ab14e6361b81	31e11ed9-a86d-4403-97f4-0ad0fda04556	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:25.528
7a336aac-9d47-49e6-b699-2be509979df1	31e11ed9-a86d-4403-97f4-0ad0fda04556	PENDING	CANCELLED	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Doi y	2026-06-04 14:25:25.817
329289b3-138a-4afb-ab2e-6daa9e6ec455	7b4a9ff3-9a49-4b5d-84ac-8ce47f65a291	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:26.189
b4f1becc-8515-4685-a445-e71fabb3662d	7b4a9ff3-9a49-4b5d-84ac-8ce47f65a291	PENDING	CANCELLED	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	cleanup	2026-06-04 14:25:26.624
df558d04-d5d3-45dd-9464-8eb2bb469024	cf3c0c8e-40aa-4025-9580-b4c941f82ece	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:41.745
3549f13b-a16b-41be-bde0-f5489c4723a1	cf3c0c8e-40aa-4025-9580-b4c941f82ece	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:42.044
c3589bb7-a1fc-4ac3-a234-f3b3280b63d0	5066a015-de2b-4f75-acac-357c4ade16cd	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:18.72
f93d406c-2d6f-4923-8521-bfad3416c13d	5066a015-de2b-4f75-acac-357c4ade16cd	ACCEPTED	IN_PREPARATION	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:19.496
4bf3373e-c154-4d2e-83bc-07570b1a2087	5066a015-de2b-4f75-acac-357c4ade16cd	READY_FOR_PICKUP	COMPLETED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:19.845
f2935472-6ad7-407c-8fbe-546405fc1502	c4b3e273-2560-4dab-ab8a-64c3afb68727	PENDING	ACCEPTED	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:20.557
a8e5f448-05ba-4988-b145-39696ac5763e	c4b3e273-2560-4dab-ab8a-64c3afb68727	IN_PREPARATION	DELIVERING	90d6537e-9af8-48c1-8c44-acc1bac26dec	\N	2026-06-04 14:25:20.938
09170f77-e48f-45f6-bc07-75b13e5cdbfe	6a92f954-1fb8-4cbd-a9aa-7423dde45627	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:21.329
8355ea4e-62df-498b-bb63-e9dab375fb02	6a92f954-1fb8-4cbd-a9aa-7423dde45627	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	selftest	2026-06-04 14:25:21.938
9d1681b8-a53b-4343-8e84-835f831b11dc	932e0a80-ad20-4c57-87e1-45770d409aa7	\N	PENDING	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	Order placed	2026-06-04 14:25:24.895
742b2c08-b32e-4fa0-a35d-a1353d4c3e97	932e0a80-ad20-4c57-87e1-45770d409aa7	ACCEPTED	SENT_TO_KITCHEN	90d6537e-9af8-48c1-8c44-acc1bac26dec	Transferred to central kitchen	2026-06-04 14:25:25.298
\.


ALTER TABLE public."OrderStatusEvent" ENABLE TRIGGER ALL;

--
-- Data for Name: Payment; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Payment" DISABLE TRIGGER ALL;

COPY public."Payment" (id, "orderId", provider, "providerRef", amount, currency, status, "rawPayload", "createdAt", "updatedAt") FROM stdin;
54d54a32-ed65-4e03-ba57-c21a2f49c244	f0a0d840-5792-4d71-bb97-b1bfb80ed10d	CASH	f0a0d840-5792-4d71-bb97-b1bfb80ed10d	620000.00	VND	CAPTURED	\N	2026-05-10 09:25:28.449	2026-05-10 09:31:41.361
ebf466b1-13f3-40e1-98a0-8448c154a8b2	c2a3e00d-5319-4144-84b4-eff3d58b0659	VNPAY	BAN-2026-YTLYFE-05464278825518	420000.00	VND	INITIATED	{"vnp_Amount": "42000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-YTLYFE-05464278825518", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan order BAN-2026-YTLYFE", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260511174638", "vnp_SecureHash": "49c7eb64d44fb2722c5f7f59aaddef56e1df2fc8b0d4c5100848e0381989aa63817a79eedef8c68889cd95b73e9c1cd45ab3b7a3ba47399d6591f001898fd25b"}	2026-05-11 10:46:38.532	2026-05-11 10:46:38.532
af6fdb9b-e9b5-47d6-8fa3-9d2235d91364	d8789680-e784-4186-8c35-27863524ca68	VNPAY	BAN-2026-QF3Y4K-40789511703488	240000.00	VND	INITIATED	{"vnp_Amount": "24000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-QF3Y4K-40789511703488", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-QF3Y4K", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260511174959", "vnp_SecureHash": "249f8a8bf727cbb4c4479e53fdc166ef12c3c5e76cbb312c56246a308c6467dffef4cec9e008775fcf954251dd33df1e158a2f0e1433992011ad5e27027d0c1b"}	2026-05-11 10:49:59.353	2026-05-11 10:49:59.353
409b446d-52d7-4c1f-8181-9be3b32314e8	048a1b04-4f67-4b24-9056-5fa16c1d0b0f	VNPAY	BAN-2026-HP8ZH3-69993750447118	420000.00	VND	INITIATED	{"vnp_Amount": "42000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-HP8ZH3-69993750447118", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-HP8ZH3", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260511175109", "vnp_SecureHash": "163ce365730bc1fabf21f160c8beaffd2890a9d52320e108aeb36311d712e5dc2054bc19e24fddce024e2ccce5d9bca6e53494ad61ed85314126db9f56503ac4"}	2026-05-11 10:51:09.681	2026-05-11 10:51:09.681
e4780c16-b09c-4a93-b5f9-3e46842275ef	81d4c479-c7be-46fd-8181-6dc4616541bb	VNPAY	BAN-2026-PSNK4N-28919541158864	240000.00	VND	INITIATED	{"vnp_Amount": "24000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-PSNK4N-28919541158864", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-PSNK4N", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260513133343", "vnp_SecureHash": "0a22e6d509028815101543b3f409980440b61c5f5bf328264c96dc308d6c615323ed08a459e36532cd05b7a7ed161c138a49b35829b21eeb8c38a6667ff5dd06"}	2026-05-13 06:33:43.342	2026-05-13 06:33:43.342
752eaa6d-6dad-43df-b9e9-fde8d61c08a2	322fdd05-ee34-4cbe-8f99-e5eb37ed5314	VNPAY	BAN-2026-AYBNAF-00120171210178	240000.00	VND	INITIATED	{"vnp_Amount": "24000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-AYBNAF-00120171210178", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-AYBNAF", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260513151123", "vnp_SecureHash": "34911662e3a8d4644488fe4605df43302e7bf6c73d6c88c63f85c663eee3aa2ae236c940454f60db7c7d96d6fd939e0293ddd8c9668ebf6f093af1991ae0d108"}	2026-05-13 08:11:23.683	2026-05-13 08:11:23.683
26d292f8-9b8e-4396-a19d-cf653ddcab5b	2e5da661-e48b-4e68-b7cd-5b5397bc3d54	VNPAY	BAN-2026-VX6M52-69027312040195	420000.00	VND	INITIATED	{"vnp_Amount": "42000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-VX6M52-69027312040195", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-VX6M52", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260513151442", "vnp_SecureHash": "c0fc0de20a2c69a43bdfbdaeaa41b2d65249994fc94366c4bbbf8bd4a7901053f076f6bbf637c531b8c0e41dfddb691c1f9243dfa9e7fda8249948397ca23e70"}	2026-05-13 08:14:42.708	2026-05-13 08:14:42.708
40a3dd58-da06-4600-8711-087aafeaac3f	2d79c95b-ce16-459d-91cf-53d1f39edc4a	VNPAY	BAN-2026-RKHUZC-74539285373269	240000.00	VND	INITIATED	{"vnp_Amount": "24000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-RKHUZC-74539285373269", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-RKHUZC", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260513165747", "vnp_SecureHash": "e1a3262954c22d93a178d888f4fc683d6c035c9ee408ebaa9586eb781fa79c7f00924726f10ba75b2d4d42c28bc8b1b09c10417ab8c0341190a2cfe4031c8350"}	2026-05-13 09:57:47.592	2026-05-13 09:57:47.592
7fdbdfaa-26f2-42cd-ae63-d35654395191	cff6b826-0ffa-4458-96bb-ca30dd0e310b	VNPAY	BAN-2026-3GXMGC-26631685493756	240000.00	VND	INITIATED	{"vnp_Amount": "24000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-3GXMGC-26631685493756", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-3GXMGC", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260513172358", "vnp_SecureHash": "94d259edb48a21e27083d83d63ec85bb58b9ae72f438c5bbd63222ffcc166bd5afd2b22f2077a4fd6106eb3bddaab6aa3e09fdfc6df44395885e4c914544aff7"}	2026-05-13 10:23:58.105	2026-05-13 10:23:58.105
cabcd6d6-5de8-4cf5-88a6-712d21eb0ca3	36cb2b2b-f0e8-44b5-bc59-23931e320913	VNPAY	BAN-2026-UHW22V-32944141277732	240000.00	VND	INITIATED	{"vnp_Amount": "24000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-UHW22V-32944141277732", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-UHW22V", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260513172736", "vnp_SecureHash": "490225923ccd31217751d48e98e32010005664760ab5533d01568fb825bead9009b8cbe9093c55a642d963ef30fd368e9abaabcf2a14e64f599ba14f771b507d"}	2026-05-13 10:27:36.205	2026-05-13 10:27:36.205
d20f0542-d287-4128-a39c-c7995a3cba2c	060470be-e651-4d99-b519-9ea5491effd9	VNPAY	BAN-2026-HK7TLK-21288457232927	240000.00	VND	INITIATED	{"vnp_Amount": "24000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-HK7TLK-21288457232927", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-HK7TLK", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260514120749", "vnp_SecureHash": "88811dbeac661e12ab987359bab1a8b1143231a6d0101f075e9f272937f31183e08ba47ec6f48523e4432a257309fd52510a79e1c5e725472902ce7aabddfc4e"}	2026-05-14 05:07:49.823	2026-05-14 05:07:49.823
5b85c3d6-696b-45e6-abf3-a395dadaa944	c47b501f-763d-4a2d-bf4b-2377d8c39b6f	VNPAY	BAN-2026-BLMXZS-73740327353083	420000.00	VND	INITIATED	{"vnp_Amount": "42000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-BLMXZS-73740327353083", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-BLMXZS", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260515175149", "vnp_SecureHash": "7e51e39b46d6fd54849ea912f9144ea4025049e8406ef1d5e591a78b06b757290444c0fd5d992db2356a6800d698d3a085dd157b25e3fabf6863bd56b653a3b2"}	2026-05-15 10:51:49.353	2026-05-15 10:51:49.353
87198ddd-61c1-49d0-8ba0-4f0f2877ec34	54081945-a072-4dc5-924c-60aa005a4344	VNPAY	BAN-2026-LLLP8B-26520441880518	560000.00	VND	INITIATED	{"vnp_Amount": "56000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-LLLP8B-26520441880518", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-LLLP8B", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260515175612", "vnp_SecureHash": "b81c7635fda3b40e393dd487de40738891f1fda13de9c8b43a32f7c8842ee3108f2949ed765468a76f26f06a0a0b3ff05935ecb18bc9dbc30850f390a16dbc84"}	2026-05-15 10:56:12.968	2026-05-15 10:56:12.968
0a88ac50-4b65-4360-bade-d036a659b5df	a2476e33-44d3-4c2b-ad4d-798099f6522c	VNPAY	BAN-2026-CCNMLX-67571554039126	240000.00	VND	INITIATED	{"vnp_Amount": "24000000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-CCNMLX-67571554039126", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-CCNMLX", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260515180051", "vnp_SecureHash": "5e845d4365f962a125b04509b46f5571933f8432e567513704691f9982bcad3f29334c4260980e8689025ee55f88280c87356886c77bfb9a57f4fb2b39e1bfc9"}	2026-05-15 11:00:51.805	2026-05-15 11:00:51.805
122ba6ae-2b3f-4ae8-a122-5e356a9523eb	7da53799-e88f-459c-b0ec-c988e7d8793a	VNPAY	BAN-2026-MWP96E-37904544681916	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-MWP96E-37904544681916", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-MWP96E", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527114533", "vnp_SecureHash": "66eae301ad6e9fdf64ac9d9fdf2b9ac4fff13bc051856c560b86ffb512a89072e082074fe2ce3b15e9af32d0e975f7b775855c24bfe3f752229ebb27ba0e51e7"}	2026-05-27 04:45:33.426	2026-05-27 04:45:33.426
d0b4cc5c-0b71-460f-ab74-a0f596f5c00d	0a6067cb-cfb2-4be0-b5c7-4d98fe27129e	VNPAY	BAN-2026-J9LFFY-81964481210121	87000.00	VND	INITIATED	{"vnp_Amount": "8700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-J9LFFY-81964481210121", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-J9LFFY", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527114534", "vnp_SecureHash": "f60f50f61de7383f83ab9da0c17f6ea53820f860f5705482ce45e4d9ee4436a8b125e5c87b9a52be4c1327a9210fe5c08ff90e0159d000176046282e30a0f215"}	2026-05-27 04:45:34.26	2026-05-27 04:45:34.26
c5d9aaef-0696-4a5c-81fe-cb3edf362ab3	c573a2c0-ab99-4fe5-a4fb-6807a578688c	VNPAY	BAN-2026-HX6RBH-50352899691624	769100.00	VND	INITIATED	{"vnp_Amount": "76910000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-HX6RBH-50352899691624", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-HX6RBH", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527114535", "vnp_SecureHash": "0caceb392e285d0cb71207c9c7dd054a0384c74fdb575834a229c076effd82cc28aa0f888ba5f919753631cb81f302efb71b8e7724bb7f4d5d054ae9063f2f2a"}	2026-05-27 04:45:35.084	2026-05-27 04:45:35.084
6198b86d-0f9d-4922-b4a8-ba17b159b1a4	71fa0429-dd11-429a-8d10-6444d48180df	VNPAY	BAN-2026-DX7B92-90171405891765	809100.00	VND	INITIATED	{"vnp_Amount": "80910000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-DX7B92-90171405891765", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-DX7B92", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527114536", "vnp_SecureHash": "89d4404153c7b45e6725190f5d1385f432bcd371dfb06cb5d357be9bc5acbaafd4d5739bee21672a8778da7ad398d5be6942fac900835fee5e7b114492725e01"}	2026-05-27 04:45:36.159	2026-05-27 04:45:36.159
d18c9d24-4e91-405c-8b66-f29fc27deebe	1e848d09-56e4-4f97-892a-491cbed7c625	CASH	1e848d09-56e4-4f97-892a-491cbed7c625	57000.00	VND	AUTHORIZED	\N	2026-05-27 04:45:37.172	2026-05-27 04:45:37.172
458007db-ce8b-4a5c-844b-185a275ead6f	06d2dfdf-83cb-4485-95f4-e83287e72c6f	VNPAY	BAN-2026-QCMKBJ-57547307894023	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-QCMKBJ-57547307894023", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-QCMKBJ", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527132328", "vnp_SecureHash": "6c3d711e07384e8cac2a31d7ebcc362959270e0053428e9d02a82ae3a02e798456ce54562c38d3fec992486d7533521f44517ff870ed5218db0b842753f48306"}	2026-05-27 06:23:28.167	2026-05-27 06:23:28.167
2636c637-5805-4c15-8b1f-29109b899a46	8b0aaca7-6e78-4010-b988-cc241b9f0e34	VNPAY	BAN-2026-GFKZ64-49271991759283	87000.00	VND	INITIATED	{"vnp_Amount": "8700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-GFKZ64-49271991759283", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-GFKZ64", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527132329", "vnp_SecureHash": "76c30422f9316d3f5a18b2999d318c6ff92e3f71b4e11b715c4fccd10f5674d05c34d953f639931340e3b55306f2f26b21cf47b43cb00ee6598d3a31abb82fc6"}	2026-05-27 06:23:29.07	2026-05-27 06:23:29.07
8a5b83f8-f199-45b5-85c3-26234a76e673	3c3a9c52-ccfd-4669-ae34-b8c1ab660813	VNPAY	BAN-2026-VNGSTK-22667322832249	769100.00	VND	INITIATED	{"vnp_Amount": "76910000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-VNGSTK-22667322832249", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-VNGSTK", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527132330", "vnp_SecureHash": "5e3784be86c9a57ec41cf48e87e9b2223f44566f20b233f8e0f2e8f41d4832b84909b909a47d7630722b49abcf7e373c1fb9a3d784cdfaf8152ea82a2aea5364"}	2026-05-27 06:23:30.069	2026-05-27 06:23:30.069
d78acd19-d047-4181-8d3a-731134c80b3a	ea013a43-7376-4e96-aaa1-04eee039bf28	VNPAY	BAN-2026-9DFQ5J-13683870505104	809100.00	VND	INITIATED	{"vnp_Amount": "80910000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-9DFQ5J-13683870505104", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-9DFQ5J", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527132331", "vnp_SecureHash": "fd391bd59ef7a414780ee3ffc996e1449032542e6fa16bf6950ebb924a466c196d89d1d909f694b54e66f318b11a08d64149dfbe348adcff9ef9c7f3efc7e01f"}	2026-05-27 06:23:31.217	2026-05-27 06:23:31.217
4f77c846-6f0a-4df0-98e8-c8fa848a39e9	7fd35beb-5d8a-4f76-b6f8-125abe027dc2	CASH	7fd35beb-5d8a-4f76-b6f8-125abe027dc2	57000.00	VND	AUTHORIZED	\N	2026-05-27 06:23:32.181	2026-05-27 06:23:32.181
bc028fa1-6c55-4260-b282-136ceac8bb8d	0d216cb1-a7fe-43ed-b2c1-a03a6d465eb5	CASH	0d216cb1-a7fe-43ed-b2c1-a03a6d465eb5	739100.00	VND	AUTHORIZED	\N	2026-05-28 14:56:53.841	2026-05-28 14:56:53.841
9b21178b-cd64-44a6-98ba-1e030fa05464	f1c3e99c-31d6-4973-be27-21ef727fc522	CASH	f1c3e99c-31d6-4973-be27-21ef727fc522	739100.00	VND	AUTHORIZED	\N	2026-05-28 14:57:01.17	2026-05-28 14:57:01.17
239a98e0-48a8-4f96-bb08-0d721cbc9975	360b1f6b-906b-49db-b7e3-67541b684874	VNPAY	BAN-2026-TLQH3L-17401535602368	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-TLQH3L-17401535602368", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-TLQH3L", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527132357", "vnp_SecureHash": "ce997357bac1b04484ebd2d0ff03a1a099829cb8bed877556820bdd01a087aa04d73fe28194ec44f418d03d0fb0aa4b8e53efede668d8549a843cb4af33cdb46"}	2026-05-27 06:23:57.602	2026-05-27 06:23:57.602
23bf5cb8-2fbf-40f2-961e-72bc1139638e	f4221321-a57b-4002-a94f-0d93688d71c1	VNPAY	BAN-2026-W85P6L-72575712822691	87000.00	VND	INITIATED	{"vnp_Amount": "8700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-W85P6L-72575712822691", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-W85P6L", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527132358", "vnp_SecureHash": "e82c6845c8f86546a2c0f3b357e003879876bbaff2f803a9ee8b9901db0296a5ee98902a814cb0e51939cdc454d2e17921bbbd24369eb11cbccd2037d459d379"}	2026-05-27 06:23:58.428	2026-05-27 06:23:58.428
b88ed277-691d-41db-a751-7f5e986883c1	71e6adfe-e78e-454c-adb3-bee43493df48	VNPAY	BAN-2026-B7W3FW-38875249450477	769100.00	VND	INITIATED	{"vnp_Amount": "76910000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-B7W3FW-38875249450477", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-B7W3FW", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527132359", "vnp_SecureHash": "b573aaf891262b604e10e8417b00210ddc259a14f4c5227370f8c865db3d5afb054c3b6607640933161ffdbdded2395ed10aea4d0553697783fc56f9cbd95637"}	2026-05-27 06:23:59.294	2026-05-27 06:23:59.294
6835a1cf-ff30-4be5-8424-5d652a587971	415d8f50-24cc-47ad-a356-e65c5a126a36	VNPAY	BAN-2026-ZPY4FT-38099223932302	809100.00	VND	INITIATED	{"vnp_Amount": "80910000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-ZPY4FT-38099223932302", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-ZPY4FT", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260527132400", "vnp_SecureHash": "a00bfc7415b49692e3949f4cfed3150a43320092728767affdc38b19713044961844755acebcafb68cd698f7f2e47b95053c5fe4dd00d21913892ccd414478a0"}	2026-05-27 06:24:00.299	2026-05-27 06:24:00.299
a441e496-e4d2-478f-8049-304a2c2fe350	930a41c4-0cd0-44a3-80d0-f1dec0a7987d	CASH	930a41c4-0cd0-44a3-80d0-f1dec0a7987d	57000.00	VND	AUTHORIZED	\N	2026-05-27 06:24:01.206	2026-05-27 06:24:01.206
8d652e5f-f15f-4b83-b898-323b101c2030	f416ccc5-c756-4486-a4f6-21000213936e	CASH	f416ccc5-c756-4486-a4f6-21000213936e	57000.00	VND	AUTHORIZED	\N	2026-05-27 07:07:05.877	2026-05-27 07:07:05.877
b79571f7-8385-4b99-a18f-ef30663aee2e	6ac99d21-6d61-4c1b-9bc3-8f222cfd44f3	CASH	6ac99d21-6d61-4c1b-9bc3-8f222cfd44f3	114000.00	VND	AUTHORIZED	\N	2026-05-28 10:33:53.011	2026-05-28 10:33:53.011
b23dcf9b-1122-48f0-bd06-6c80e197a8b0	c1bd6aa5-4b8c-4905-ab85-d0f6116c26d2	CASH	c1bd6aa5-4b8c-4905-ab85-d0f6116c26d2	114000.00	VND	AUTHORIZED	\N	2026-05-28 10:36:25.62	2026-05-28 10:36:25.62
7d54a1cb-02a3-4ab3-b174-c8cc439e749b	aabdd124-5231-4e59-9662-5eabcbb12a35	CASH	aabdd124-5231-4e59-9662-5eabcbb12a35	739100.00	VND	AUTHORIZED	\N	2026-05-28 10:36:26.511	2026-05-28 10:36:26.511
21db5515-6fe8-4e0a-940a-7a0f26232a8e	391c5fe3-1d1e-4faa-951a-53d408672097	CASH	391c5fe3-1d1e-4faa-951a-53d408672097	114000.00	VND	AUTHORIZED	\N	2026-05-28 12:55:06.376	2026-05-28 12:55:06.376
3a60e594-2bc6-4475-abaa-d1240bc6ae2e	da82ec7c-c33d-42ef-9e7c-11407ad56658	CASH	da82ec7c-c33d-42ef-9e7c-11407ad56658	739100.00	VND	AUTHORIZED	\N	2026-05-28 12:55:07.401	2026-05-28 12:55:07.401
6672da99-5be5-4bb4-8257-8d17bacb9216	67c580fc-477a-4f1d-aedc-64f40fe57801	CASH	67c580fc-477a-4f1d-aedc-64f40fe57801	114000.00	VND	AUTHORIZED	\N	2026-05-28 12:55:47.157	2026-05-28 12:55:47.157
dfca9d01-cbcb-4dfc-ab1c-8b2b78e95591	576af804-e9d9-4a8e-96ae-b38b32ab78f2	CASH	576af804-e9d9-4a8e-96ae-b38b32ab78f2	739100.00	VND	AUTHORIZED	\N	2026-05-28 12:55:47.943	2026-05-28 12:55:47.943
6daeb071-e082-4a80-a05f-7c0acde77031	8945b8b2-4342-42f7-b118-0f86ab8be729	CASH	8945b8b2-4342-42f7-b118-0f86ab8be729	351500.00	VND	AUTHORIZED	\N	2026-05-28 12:56:11.052	2026-05-28 12:56:11.052
7eb648fc-2c89-4fcb-9aae-ea62c74b9441	4477228e-355c-44c3-aa66-006060651356	CASH	4477228e-355c-44c3-aa66-006060651356	739100.00	VND	AUTHORIZED	\N	2026-05-28 13:42:40.875	2026-05-28 13:42:40.875
fc4f4947-c9a6-480e-9774-42b16415d728	d1711b85-ffa7-471c-82fa-a2fc8e7d8257	CASH	d1711b85-ffa7-471c-82fa-a2fc8e7d8257	114000.00	VND	AUTHORIZED	\N	2026-05-28 13:45:05.564	2026-05-28 13:45:05.564
9404a5cf-c63c-4f2a-a1b0-c5f75c476ab8	1fac125a-c877-4b7c-9df5-c38a5baf89d7	CASH	1fac125a-c877-4b7c-9df5-c38a5baf89d7	739100.00	VND	AUTHORIZED	\N	2026-05-28 13:45:06.477	2026-05-28 13:45:06.477
0419c418-a7aa-4f47-871b-e4d13f01f85b	4ce0cf06-7d6f-4da4-b7b3-f50a995f0e81	CASH	4ce0cf06-7d6f-4da4-b7b3-f50a995f0e81	739100.00	VND	AUTHORIZED	\N	2026-05-28 13:45:13.756	2026-05-28 13:45:13.756
a43fd7a4-af2b-4db9-9a28-977bfc92863f	d54352b3-9021-484c-922a-8e60b62e1717	CASH	d54352b3-9021-484c-922a-8e60b62e1717	57000.00	VND	AUTHORIZED	\N	2026-05-28 13:45:14.052	2026-05-28 13:45:14.052
0fff31b8-f999-446f-a7aa-877a0c7a2daf	b2c8b6ee-c6b4-48cd-872d-44c0ee099b2a	CASH	b2c8b6ee-c6b4-48cd-872d-44c0ee099b2a	114000.00	VND	AUTHORIZED	\N	2026-05-28 13:45:46.257	2026-05-28 13:45:46.257
6409bc6c-fb9d-40a9-9cfe-c8f10c40ab56	9b591661-d213-463a-98d0-d01960d09ba8	CASH	9b591661-d213-463a-98d0-d01960d09ba8	739100.00	VND	AUTHORIZED	\N	2026-05-28 13:45:47.106	2026-05-28 13:45:47.106
b8aff744-99a1-481e-a83c-af4167783038	6839cfd4-2d2b-4d11-81e9-dff17295ec0c	CASH	6839cfd4-2d2b-4d11-81e9-dff17295ec0c	739100.00	VND	AUTHORIZED	\N	2026-05-28 13:45:54.042	2026-05-28 13:45:54.042
a4aa2c0f-c048-4115-8200-19c84c147629	1b4901e5-9a3d-4c2c-a66a-19395b5f3eb7	CASH	1b4901e5-9a3d-4c2c-a66a-19395b5f3eb7	57000.00	VND	AUTHORIZED	\N	2026-05-28 13:45:54.387	2026-05-28 13:45:54.387
0fd3c4ef-3e68-494e-ab62-62374c8bab08	1613cc7c-ebbb-4ce0-8d04-b487547caef2	CASH	1613cc7c-ebbb-4ce0-8d04-b487547caef2	114000.00	VND	AUTHORIZED	\N	2026-05-28 13:51:09.819	2026-05-28 13:51:09.819
766874c7-94d1-4c49-a36d-738cb20d88d0	e03a6eae-b28f-40b4-a2e6-ea43077690e4	CASH	e03a6eae-b28f-40b4-a2e6-ea43077690e4	739100.00	VND	AUTHORIZED	\N	2026-05-28 13:51:10.735	2026-05-28 13:51:10.735
022e8423-269c-4bae-8e1f-40942743478e	d09490bc-4a8a-4e90-bca2-2993b580cd02	CASH	d09490bc-4a8a-4e90-bca2-2993b580cd02	114000.00	VND	AUTHORIZED	\N	2026-05-28 13:51:15.937	2026-05-28 13:51:15.937
dfd83386-017e-4480-8876-6343a279724d	99e18f60-be97-4690-b088-46e2d4df8f46	CASH	99e18f60-be97-4690-b088-46e2d4df8f46	739100.00	VND	AUTHORIZED	\N	2026-05-28 13:51:17.064	2026-05-28 13:51:17.064
e20aa776-f722-4041-9104-9ff5f6114483	c8de4f77-6501-467f-a7c5-a70cbc551d40	CASH	c8de4f77-6501-467f-a7c5-a70cbc551d40	739100.00	VND	AUTHORIZED	\N	2026-05-28 13:51:19.849	2026-05-28 13:51:19.849
d731c4bb-ef30-4857-96f9-1bc81a5292d6	2c8c866b-ba60-4941-985f-25d5fc8e4080	CASH	2c8c866b-ba60-4941-985f-25d5fc8e4080	57000.00	VND	AUTHORIZED	\N	2026-05-28 13:51:20.276	2026-05-28 13:51:20.276
c06b5176-a8a3-4411-8c75-14569be172e5	2b6d0ea0-e8a9-45a7-815b-19d89c8ecacd	CASH	2b6d0ea0-e8a9-45a7-815b-19d89c8ecacd	739100.00	VND	AUTHORIZED	\N	2026-05-28 13:51:25.909	2026-05-28 13:51:25.909
960e2ac7-27ae-4085-bf07-5cde8d274bcf	54d39164-20eb-4ee8-bfed-9308c4ac5c6d	CASH	54d39164-20eb-4ee8-bfed-9308c4ac5c6d	57000.00	VND	AUTHORIZED	\N	2026-05-28 13:51:26.187	2026-05-28 13:51:26.187
655c183d-df3b-4712-841b-0bdf3bb0b16d	1f62576c-5b36-433b-816a-54ed7730a30d	CASH	1f62576c-5b36-433b-816a-54ed7730a30d	114000.00	VND	AUTHORIZED	\N	2026-05-28 14:56:52.837	2026-05-28 14:56:52.837
4d009601-c58d-458c-aca9-a4005d233b64	50f3345d-7363-4dd7-98e3-1544baa8b598	CASH	50f3345d-7363-4dd7-98e3-1544baa8b598	57000.00	VND	AUTHORIZED	\N	2026-05-28 14:57:01.484	2026-05-28 14:57:01.484
5bc80643-f3ee-4329-85cc-e9fb75a9aa85	f0c33315-a5c8-4b7c-a086-c9e828ceaa19	CASH	f0c33315-a5c8-4b7c-a086-c9e828ceaa19	57000.00	VND	CAPTURED	\N	2026-05-28 18:31:25.732	2026-05-28 18:31:26.722
0255deb8-000a-4db8-8d54-de3ab60cde64	e387ebf2-adc9-4618-91d8-5daaab86e242	CASH	e387ebf2-adc9-4618-91d8-5daaab86e242	175750.00	VND	AUTHORIZED	\N	2026-05-29 06:54:13.939	2026-05-29 06:54:13.939
0e068bd8-2ed8-4ab7-9255-569edf4dd3a6	850899fc-8c0d-42ea-bb52-1e805cf6fb1b	CASH	850899fc-8c0d-42ea-bb52-1e805cf6fb1b	114000.00	VND	AUTHORIZED	\N	2026-05-29 08:01:17.44	2026-05-29 08:01:17.44
ebf40ba1-e75d-4f3c-b112-c0d7c1771725	caf835e3-6fff-4edd-96d7-f90025c415b0	CASH	caf835e3-6fff-4edd-96d7-f90025c415b0	739100.00	VND	AUTHORIZED	\N	2026-05-29 08:01:17.658	2026-05-29 08:01:17.658
86b23a05-0e32-4648-9955-14efd2877380	be91f242-979e-4a53-b593-8d7f20bd243c	CASH	be91f242-979e-4a53-b593-8d7f20bd243c	175750.00	VND	AUTHORIZED	\N	2026-05-29 08:01:17.94	2026-05-29 08:01:17.94
80d2f0b4-e8f2-403e-bd01-389e0e457168	08c983fd-7a1d-4a55-9f10-ca8cb03d231f	CASH	08c983fd-7a1d-4a55-9f10-ca8cb03d231f	796100.00	VND	AUTHORIZED	\N	2026-05-29 08:01:18.459	2026-05-29 08:01:18.459
d2256d2a-d14f-4ac9-8ebd-dba6aa074c22	59137e9e-e71c-4fe7-80e1-2c071b3ac15e	CASH	59137e9e-e71c-4fe7-80e1-2c071b3ac15e	60000.00	VND	AUTHORIZED	\N	2026-05-29 08:01:19.43	2026-05-29 08:01:19.43
1a90c1c4-79ff-4e43-b71d-1cc0ac8df3e0	fb138522-366c-42f5-a37b-6468cfc2b21a	VNPAY	BAN-2026-TLTRK8-52275115460440	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-TLTRK8-52275115460440", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-TLTRK8", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260529150119", "vnp_SecureHash": "03d47e0a8afda0d39fa99d9ff0c4fe19c527206e292479fc399dc69135370518e56c0e535fb64c0d113095b633241e248fe6cf24eec4fce154bb902922c68c0f"}	2026-05-29 08:01:19.662	2026-05-29 08:01:19.662
ab89e2cb-9481-44b7-b057-e2fc164d6a62	94d6b88e-0960-442f-b479-fd1737296478	CASH	94d6b88e-0960-442f-b479-fd1737296478	57000.00	VND	CAPTURED	\N	2026-05-29 08:01:20.292	2026-05-29 08:01:21.426
c1d151a4-0bbe-4f09-a5f3-5a6d66fdcf91	f6ba4a2b-2161-4e3d-b051-2c15d8d2fc0c	VNPAY	BAN-2026-V8F3Y9-26274720442353	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-V8F3Y9-26274720442353", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-V8F3Y9", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260529150121", "vnp_SecureHash": "ae81dcf8cc69fcdf25920f7e6ffa740e13486551e28baf886c909b8f927c1b6ff7c237fa88eee7d7f5b77475045d554d611eba16c1027c11c47409b37c153f80"}	2026-05-29 08:01:21.726	2026-05-29 08:01:21.726
8e8bc25d-1166-4b0d-8132-c60bfc1bddf1	97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2	CASH	97bb1e6c-76b8-4a3c-b6d4-14308f0cc5f2	739100.00	VND	CAPTURED	\N	2026-05-29 08:01:23.017	2026-05-29 08:01:24.95
c6eb18b5-e289-49d7-b60d-eab4285fc7c3	3dfa2152-e081-405f-af1c-01cf28f36833	VNPAY	BAN-2026-X9RCYA-35441716372844	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-X9RCYA-35441716372844", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-X9RCYA", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260529150125", "vnp_SecureHash": "d3a16f38007303ebeb5206d669e2c21d7a2fa81f95dbe20234f5e421daca67682e68d271a86c55babba0094dd870cca68d8008cf2a44c30d1ea9feedee8a437e"}	2026-05-29 08:01:25.23	2026-05-29 08:01:25.23
02e4b636-0de1-4004-ae32-480103e5d5e1	333f3385-3ef1-468a-b268-0d58e4b8d4d5	CASH	333f3385-3ef1-468a-b268-0d58e4b8d4d5	57000.00	VND	AUTHORIZED	\N	2026-05-29 08:01:26.785	2026-05-29 08:01:26.785
1561fdbc-6deb-4cfd-87e1-a3231b883dcf	914b19c3-d8ad-46fe-a486-7ca8365ec2b7	CASH	914b19c3-d8ad-46fe-a486-7ca8365ec2b7	57000.00	VND	AUTHORIZED	\N	2026-05-29 08:01:27.509	2026-05-29 08:01:27.509
1c501892-1327-4af4-969b-821d7e8d4d93	4b2619c3-53b2-4070-9d2d-40493747d077	CASH	4b2619c3-53b2-4070-9d2d-40493747d077	57000.00	VND	AUTHORIZED	\N	2026-05-29 08:01:28.415	2026-05-29 08:01:28.415
1874cd9c-c0a0-40c0-9d0e-1af638335686	e700e920-338a-4b4c-be66-35653f8d8302	CASH	e700e920-338a-4b4c-be66-35653f8d8302	57000.00	VND	AUTHORIZED	\N	2026-05-29 08:02:41.827	2026-05-29 08:02:41.827
e9a01f81-853a-4f9d-8717-d7cb0dc1a038	32dcda4c-0995-4645-a367-a97d7d9a9be3	CASH	32dcda4c-0995-4645-a367-a97d7d9a9be3	114000.00	VND	AUTHORIZED	\N	2026-06-02 08:57:31.156	2026-06-02 08:57:31.156
f013671d-5750-4395-96f7-44e8321dc473	cfd9e126-956f-4032-847b-8593ece91985	CASH	cfd9e126-956f-4032-847b-8593ece91985	739100.00	VND	AUTHORIZED	\N	2026-06-02 08:57:31.582	2026-06-02 08:57:31.582
394c14f9-5e54-4c7d-807e-14565f555ef1	5cc96b01-2502-445c-afd4-34c05f6196b6	CASH	5cc96b01-2502-445c-afd4-34c05f6196b6	175750.00	VND	AUTHORIZED	\N	2026-06-02 08:57:31.985	2026-06-02 08:57:31.985
d39d280c-bcad-4365-b9fc-83a2ae4b9fbf	02ff0412-d0f6-4619-8263-c6c4b4d4b6a1	CASH	02ff0412-d0f6-4619-8263-c6c4b4d4b6a1	796100.00	VND	AUTHORIZED	\N	2026-06-02 08:57:32.687	2026-06-02 08:57:32.687
bdeb7237-e71e-4c66-8a54-69857fd67099	ae1b56a6-baef-45fc-bdcc-b66841201677	CASH	ae1b56a6-baef-45fc-bdcc-b66841201677	60000.00	VND	AUTHORIZED	\N	2026-06-02 08:57:34.215	2026-06-02 08:57:34.215
bbd375bf-7edb-43bc-b369-57ccf45e1fbe	2cc97ad0-2af0-4b4b-9bea-94e4383e4628	VNPAY	BAN-2026-ENND3U-38000114932152	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-ENND3U-38000114932152", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-ENND3U", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260602155734", "vnp_SecureHash": "e8831b6f1f9882334dd26eb53aeb630a37fccab1ae6eb509bea8a0bd1305fe6b930c9a975562b086454b65bd7178ae52fd02090c65d0d3f58256ad105ff888de"}	2026-06-02 08:57:34.61	2026-06-02 08:57:34.61
351e4976-1b00-4a17-af9f-6678969a82af	79696db8-7e3d-4408-89aa-d5010de88388	CASH	79696db8-7e3d-4408-89aa-d5010de88388	57000.00	VND	CAPTURED	\N	2026-06-02 08:57:35.321	2026-06-02 08:57:36.748
ccfc2e16-9f1d-47f1-b751-55544b415d76	ef97c0c0-67be-4cce-aa98-efa1aa3a74bc	VNPAY	BAN-2026-6JESW4-65087995486677	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-6JESW4-65087995486677", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-6JESW4", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260602155737", "vnp_SecureHash": "40a7495b75162db9d3ff825993a92eb406cfd27240df78569ccf36da689d602ec54ff56bc50810aad316f32da73c0d63e0dcb924e4dbffde59bcf44038006718"}	2026-06-02 08:57:37.104	2026-06-02 08:57:37.104
66c1a164-44be-41e4-99c0-8e6156c87338	22cb5aaf-7cd9-4483-8232-0209b84636b6	CASH	22cb5aaf-7cd9-4483-8232-0209b84636b6	739100.00	VND	CAPTURED	\N	2026-06-02 08:57:38.576	2026-06-02 08:57:40.883
5680da20-a2fb-4208-8dc8-392469845bdf	05c829ec-c0fd-41b1-9c05-102bd43439a6	VNPAY	BAN-2026-84N9Q3-61613290489600	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-84N9Q3-61613290489600", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-84N9Q3", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260602155741", "vnp_SecureHash": "4ac68ffb93ee7b0849d5a6b1fc0d565214015ad1db463171b0b017326494946bade8bdfe0560ffb4ddbe3f0e31cae35b97a6d3bfb15870f2e9c703f5c0549db1"}	2026-06-02 08:57:41.177	2026-06-02 08:57:41.177
2ebbe981-5799-49eb-9473-e0270f042bc5	031479dc-1160-471b-a16f-cce9ff1625f6	CASH	031479dc-1160-471b-a16f-cce9ff1625f6	57000.00	VND	AUTHORIZED	\N	2026-06-02 08:57:42.854	2026-06-02 08:57:42.854
de2b7c93-ce14-4087-ad6b-ebcc81b767a1	d65f2099-6c4d-456c-8dc2-87d357842f4c	CASH	d65f2099-6c4d-456c-8dc2-87d357842f4c	57000.00	VND	VOIDED	\N	2026-06-02 08:57:43.613	2026-06-02 08:57:43.894
e0c45db0-24ee-41c4-aeac-21d883565f08	a3236cb6-463b-4402-8bc7-fcbd666257d6	CASH	a3236cb6-463b-4402-8bc7-fcbd666257d6	57000.00	VND	VOIDED	\N	2026-06-02 08:57:44.331	2026-06-02 08:57:44.812
2f235479-a939-42ae-86c5-21cc634a5c4f	f5158425-e1b1-48a9-bca8-8e4bf4fa337d	CASH	f5158425-e1b1-48a9-bca8-8e4bf4fa337d	57000.00	VND	AUTHORIZED	\N	2026-06-02 10:34:27.138	2026-06-02 10:34:27.138
71ff815a-7be2-49d1-b1dc-4475a58f0f77	a70eece6-5748-4365-a6ab-990aaf2249cf	CASH	a70eece6-5748-4365-a6ab-990aaf2249cf	57000.00	VND	AUTHORIZED	\N	2026-06-02 10:54:09.854	2026-06-02 10:54:09.854
ebfcfe81-575a-4553-ac88-3ccdf0df7c06	67f14c8a-c137-4a45-974c-45ab1df77460	CASH	67f14c8a-c137-4a45-974c-45ab1df77460	739100.00	VND	AUTHORIZED	\N	2026-06-02 11:09:20.448	2026-06-02 11:09:20.448
bffb85b4-19a6-46c0-9eb5-21b8c75984a4	671dcde8-bf46-4361-9302-38ba388c2577	VNPAY	BAN-2026-LQPC7H-26658814771556	769100.00	VND	INITIATED	{"vnp_Amount": "76910000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-LQPC7H-26658814771556", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-LQPC7H", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260602180920", "vnp_SecureHash": "305d3c37eeed394ff7d873cc8ed7add951cf86b8a70c3c730ff1573e4c7b01e2654fffa97632955f89f0233add24ab417b860104de6e9d426fc7e9289df32796"}	2026-06-02 11:09:20.604	2026-06-02 11:09:20.604
1e8c537c-17b9-4520-8cb6-bd2a1453394b	175701bc-0450-4429-96d5-735e9aafcb82	CASH	175701bc-0450-4429-96d5-735e9aafcb82	0.00	VND	AUTHORIZED	\N	2026-06-04 14:11:21.268	2026-06-04 14:11:21.268
bb620426-2934-486b-8294-0bfa70c6d968	2e5538cf-93fc-4590-9858-68d6fe7e5fd6	CASH	2e5538cf-93fc-4590-9858-68d6fe7e5fd6	0.00	VND	AUTHORIZED	\N	2026-06-04 14:24:51.157	2026-06-04 14:24:51.157
8e8db1aa-6fb0-45a0-91d8-d3e54aa3df86	94e2d801-4952-476a-83d2-b0ff9d87de66	CASH	94e2d801-4952-476a-83d2-b0ff9d87de66	114000.00	VND	AUTHORIZED	\N	2026-06-04 14:25:15.811	2026-06-04 14:25:15.811
6a047691-078a-4360-9804-a4d88c55a3cb	4f927fab-084c-4a89-99d0-079e924b8819	CASH	4f927fab-084c-4a89-99d0-079e924b8819	739100.00	VND	AUTHORIZED	\N	2026-06-04 14:25:16.129	2026-06-04 14:25:16.129
b91d1833-986c-44ea-82bc-650d7e59e082	d411c7d5-fcac-48eb-9f26-3df9366f17be	CASH	d411c7d5-fcac-48eb-9f26-3df9366f17be	175750.00	VND	AUTHORIZED	\N	2026-06-04 14:25:16.442	2026-06-04 14:25:16.442
64264299-7d8b-4717-b3b8-bf5ec8bf0638	21417b81-1fe7-461d-b3ac-6bd595328a35	CASH	21417b81-1fe7-461d-b3ac-6bd595328a35	796100.00	VND	AUTHORIZED	\N	2026-06-04 14:25:17.026	2026-06-04 14:25:17.026
ce5d292b-cd07-4c22-ab0c-9b827c572210	d11bfa82-317d-4bf1-92ac-ae822d083dd8	CASH	d11bfa82-317d-4bf1-92ac-ae822d083dd8	60000.00	VND	AUTHORIZED	\N	2026-06-04 14:25:17.825	2026-06-04 14:25:17.825
6024dd84-2b76-44cc-9419-fd935de59ff3	6962c74f-4108-46dc-9f03-1d6db00a6751	VNPAY	BAN-2026-A6F9WW-50295530522406	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-A6F9WW-50295530522406", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-A6F9WW", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260604212518", "vnp_SecureHash": "303d47e633c436de51d1bd4225e019c8302da5dedffc7a9158c78584a9452af4f8874dc1431044a897fbb7d41612f5a35b422f15c80aa2cdbfd9c779d3284d4a"}	2026-06-04 14:25:18.173	2026-06-04 14:25:18.173
667b5bff-1681-424b-8e9b-69659b41377d	5066a015-de2b-4f75-acac-357c4ade16cd	CASH	5066a015-de2b-4f75-acac-357c4ade16cd	57000.00	VND	CAPTURED	\N	2026-06-04 14:25:18.745	2026-06-04 14:25:19.851
c6d729a5-5f28-407a-9ade-77268882d61a	c4b3e273-2560-4dab-ab8a-64c3afb68727	VNPAY	BAN-2026-PCNBQ9-26077566001508	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-PCNBQ9-26077566001508", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-PCNBQ9", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260604212520", "vnp_SecureHash": "9756910d857deaf855893ec5d9542d585aa9bb1922ada55be096318a71357e757e0be55bf582f7f5b5b2bc96cfd0f9f79ded27558cf6548ffcb1aa927b0806d3"}	2026-06-04 14:25:20.129	2026-06-04 14:25:20.129
3242750c-faf4-48bc-ae4d-cc23739ffd15	6a92f954-1fb8-4cbd-a9aa-7423dde45627	CASH	6a92f954-1fb8-4cbd-a9aa-7423dde45627	739100.00	VND	CAPTURED	\N	2026-06-04 14:25:21.35	2026-06-04 14:25:23.263
6fd84f28-bb44-4c66-9704-2dc6ee396073	4831b162-0d0d-40df-a1b9-5360d034f731	VNPAY	BAN-2026-PNM4ZM-87780176402162	57000.00	VND	INITIATED	{"vnp_Amount": "5700000", "vnp_IpAddr": "::1", "vnp_Locale": "vn", "vnp_TxnRef": "BAN-2026-PNM4ZM-87780176402162", "vnp_Command": "pay", "vnp_TmnCode": "STC2HT80", "vnp_Version": "2.1.0", "vnp_CurrCode": "VND", "vnp_OrderInfo": "Banan_order_BAN-2026-PNM4ZM", "vnp_OrderType": "other", "vnp_ReturnUrl": "http://localhost:3000/api/v1/payments/vnpay/return", "vnp_CreateDate": "20260604212523", "vnp_SecureHash": "abb2e114c7ba8bbc3a1cc69b9b80b78fab2637b2d6bf024009fae61bcba9795c157ccd23e38abc345ab6104f60af39a55f3bdd7c270e8a96649291b1da74c43d"}	2026-06-04 14:25:23.531	2026-06-04 14:25:23.531
8417b276-dc20-4090-b682-0a69b5d6c654	932e0a80-ad20-4c57-87e1-45770d409aa7	CASH	932e0a80-ad20-4c57-87e1-45770d409aa7	57000.00	VND	AUTHORIZED	\N	2026-06-04 14:25:24.917	2026-06-04 14:25:24.917
c31e3474-aeeb-4146-b8bf-50f8bb84ec81	31e11ed9-a86d-4403-97f4-0ad0fda04556	CASH	31e11ed9-a86d-4403-97f4-0ad0fda04556	57000.00	VND	VOIDED	\N	2026-06-04 14:25:25.545	2026-06-04 14:25:25.829
ae792f6b-3068-4c1b-95ec-816752696502	7b4a9ff3-9a49-4b5d-84ac-8ce47f65a291	CASH	7b4a9ff3-9a49-4b5d-84ac-8ce47f65a291	57000.00	VND	VOIDED	\N	2026-06-04 14:25:26.208	2026-06-04 14:25:26.634
ed789627-0a34-4982-8ae9-56dcabf99342	cf3c0c8e-40aa-4025-9580-b4c941f82ece	CASH	cf3c0c8e-40aa-4025-9580-b4c941f82ece	57000.00	VND	AUTHORIZED	\N	2026-06-04 14:25:41.768	2026-06-04 14:25:41.768
\.


ALTER TABLE public."Payment" ENABLE TRIGGER ALL;

--
-- Data for Name: PaymentMethod; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."PaymentMethod" DISABLE TRIGGER ALL;

COPY public."PaymentMethod" (id, "userId", provider, token, brand, last4, "expMonth", "expYear", "isDefault") FROM stdin;
\.


ALTER TABLE public."PaymentMethod" ENABLE TRIGGER ALL;

--
-- Data for Name: ProductionBatch; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."ProductionBatch" DISABLE TRIGGER ALL;

COPY public."ProductionBatch" (id, "kitchenId", "productId", "variantId", "plannedQty", "actualQty", "scheduledFor", status, notes, "createdAt", "updatedAt") FROM stdin;
\.


ALTER TABLE public."ProductionBatch" ENABLE TRIGGER ALL;

--
-- Data for Name: PromoPopup; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."PromoPopup" DISABLE TRIGGER ALL;

COPY public."PromoPopup" (id, "isActive", title, body, "imageUrl", "ctaLabel", "ctaUrl", "countdownSeconds", version, "updatedAt") FROM stdin;
default	t	Khai truong - Giam 20%	Mung khai truong Banan - Le Thanh Ton. Nhap ma KHAITRUONG khi thanh toan.	\N	Xem ngay	/	8	2	2026-06-02 09:52:30.078
\.


ALTER TABLE public."PromoPopup" ENABLE TRIGGER ALL;

--
-- Data for Name: RefreshToken; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."RefreshToken" DISABLE TRIGGER ALL;

COPY public."RefreshToken" (id, "userId", "tokenHash", "deviceId", "userAgent", "ipAddress", "expiresAt", "revokedAt", "createdAt") FROM stdin;
ef36a038-bd03-45c8-a851-40ec454a02f5	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	1d30926c455d60fa4b85ebb623a0740216103d0719e6ef88c97e6b9e23c5228b	\N	\N	\N	2026-06-09 06:53:09.256	\N	2026-05-10 06:53:09.259
1ab846dd-1d2d-482b-87f7-884db2d8b684	90d6537e-9af8-48c1-8c44-acc1bac26dec	efda8f09eb79d2edad32acaeff06d451d5db422aac3b6e6ad431396397879ee9	\N	\N	\N	2026-06-09 06:53:15.595	\N	2026-05-10 06:53:15.596
c60bda7a-f882-4b3b-bfaa-9a1e6abfae87	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	cd4538e05f07a91ef141b24c8f7a54abc44e1ef0030f9f5069ea75bdb0990e08	\N	\N	\N	2026-06-09 07:25:38.285	\N	2026-05-10 07:25:38.288
ea4ce421-eb7f-405b-9d88-006b6b9e6122	aedd04e8-4140-437f-b66b-0f133c42b11f	976445a3526c6b630fd6f7a1e6e3b7f772f5f424133ca43118ded462852843d5	\N	\N	\N	2026-06-09 07:47:46.605	\N	2026-05-10 07:47:46.608
44740710-fd99-41fb-a68c-06ccf70f11b4	90d6537e-9af8-48c1-8c44-acc1bac26dec	6160d8a40c3112f14058119b113fd2034d25fff37ab551b595ebe1a81a30e7bd	\N	\N	\N	2026-06-09 08:19:29.056	\N	2026-05-10 08:19:29.06
cd161fa0-bd04-4f06-aace-075e0465bf13	90d6537e-9af8-48c1-8c44-acc1bac26dec	460183d0895d170d92c61c413e1ea5ab34d9749e559a02d3852ea45ddec2e720	\N	\N	\N	2026-06-09 09:23:45.303	\N	2026-05-10 09:23:45.306
f73a4ec2-1bb0-435c-868a-1c65a5046a76	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	df4bbc61dbb343eaa84cb3870d6e03852928ede452abab302cfb9fa75efb7818	\N	\N	\N	2026-06-09 09:24:17.798	\N	2026-05-10 09:24:17.799
c185e333-bdaf-430d-84c9-f5ebee2bda2a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	8c54930ef0bdf761547eebfcb64b29b66200a4f229cee83e7656e3c41fa8ecd5	\N	\N	\N	2026-06-09 09:55:22.727	\N	2026-05-10 09:55:22.73
39f0f37c-d03a-4d06-adef-d20df8bbc673	90d6537e-9af8-48c1-8c44-acc1bac26dec	d2456695f195fdfeb098bdefa51559dd8c03c324b2f88b3e2968423bb0cf3ea9	\N	\N	\N	2026-06-09 09:56:19.265	\N	2026-05-10 09:56:19.266
01e94455-bb73-44d5-b246-ab5b0f3a2560	ab32baa0-382d-48e5-a542-b6f6a3620a9b	b8052b5a23649ff89b0d1527c951efa8d266088451c00d19c896fc6532dd4581	\N	\N	\N	2026-06-09 10:11:15.188	\N	2026-05-10 10:11:15.191
d672534d-e45b-48e0-9b18-a10f0a2bda79	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	da80de9091f3c5fd205add729733d5e08ceb9cf913f7a05b9dc5fb33beb1f85a	\N	\N	\N	2026-06-09 10:25:24.242	\N	2026-05-10 10:25:24.245
290a317e-0c4a-4c5d-9c4f-87c8c8bf1b8d	ab32baa0-382d-48e5-a542-b6f6a3620a9b	974426328694ef4231c636145a90f3f249e0b5d61cee7859404dbede34fb9c0a	\N	\N	\N	2026-06-09 15:52:28.823	\N	2026-05-10 15:52:28.825
6d7170e6-077b-4915-87b9-1c3a226a0bf4	90d6537e-9af8-48c1-8c44-acc1bac26dec	999466542016ececebf924fb51154549093d987a017517ff844e85c234be8e0b	\N	\N	\N	2026-06-09 15:53:05.005	\N	2026-05-10 15:53:05.007
d23d0e70-bfdc-42c4-93a5-48477de8eeb5	ab32baa0-382d-48e5-a542-b6f6a3620a9b	ddb1d170acba9a6de10e5610bdd651c6c738f69bfdf49809e4b01891be4903c7	\N	\N	\N	2026-06-09 18:26:44.85	\N	2026-05-10 18:26:44.853
e72be709-b4e9-41e7-9dc4-e5f7b165adff	90d6537e-9af8-48c1-8c44-acc1bac26dec	cb674728036ddc30b8719ba025ccb883211b7afd4315dddef9cb1816b9f40e32	\N	\N	\N	2026-06-09 18:27:02.019	\N	2026-05-10 18:27:02.022
30ca14ca-411f-41c7-a200-91d45ae2c68d	90d6537e-9af8-48c1-8c44-acc1bac26dec	cf65bf9da7dc418ab3fcc9ade7011aca9468a77081e4d52605452d09aa89197c	\N	\N	\N	2026-06-09 18:27:17.06	\N	2026-05-10 18:27:17.063
bb253fc4-ef52-4d32-8094-4b524bf5d73e	ab32baa0-382d-48e5-a542-b6f6a3620a9b	cdeee5a224436c4b1ef75728239c0e2ee266248cfb76d7d576af9aed12410471	\N	\N	\N	2026-06-09 18:28:11.122	\N	2026-05-10 18:28:11.123
ba24fdcd-aa5b-4d3a-9623-e0e32757a44a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	ab790337c07e147104ce81cda49298be6dcd314d195ed948bbb3180eafedcc8b	\N	\N	\N	2026-06-09 19:00:04.108	\N	2026-05-10 19:00:04.11
ca11cef8-b6af-4f0f-a2c8-1df35c1502e5	90d6537e-9af8-48c1-8c44-acc1bac26dec	4e9147f7e5702236206bd5728f1e0277e5c586d0e2dda40bac6ae8a8c1d8ef2d	\N	\N	\N	2026-06-09 19:00:38.764	\N	2026-05-10 19:00:38.766
cfa664ea-4052-4300-850e-b6557098a9c4	ab32baa0-382d-48e5-a542-b6f6a3620a9b	4ea2ac7ea4ed9b8fb1df12b047fa150d57b14d32d63b11e740d77c5ba01c4311	\N	\N	\N	2026-06-09 19:01:08.692	\N	2026-05-10 19:01:08.694
66b15b71-d6c2-47c6-8af1-bd6310f8204e	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	30998f0d3614e44e6b39da0dde41fa011a87ed48aaf8a44f335062a13e658628	\N	\N	\N	2026-06-10 03:47:30.968	\N	2026-05-11 03:47:30.97
75fb127f-603f-48a0-8458-5977c9da2d85	ab32baa0-382d-48e5-a542-b6f6a3620a9b	92f392fe38606b9ec81e7e16a12d28ece92d686e2fb8c64b1957fc5ec61913a7	\N	\N	\N	2026-06-10 03:48:28.094	\N	2026-05-11 03:48:28.096
373e96b8-ef69-4e95-a22f-46530b763066	90d6537e-9af8-48c1-8c44-acc1bac26dec	ae54002cd541bccec4bf0fe3e0f3bb386bb062c6064cf4fb8e78d95fc771de5b	\N	\N	\N	2026-06-10 04:03:18.922	\N	2026-05-11 04:03:18.923
998b0d30-da0e-47c9-9b01-78875036516a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	ee7c183ad98672b34a8f6d86d805ae7c4c5d015bbb0b17d096277d8692a297c6	\N	\N	\N	2026-06-10 07:05:06.396	\N	2026-05-11 07:05:06.399
eafa324e-66cb-472c-9e4a-89f5c113eda5	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	9627c5c89bc30c98868550eec8fedc60ebaf414b59cafb6c27e7f87a1642b398	\N	\N	\N	2026-06-10 10:46:24.692	\N	2026-05-11 10:46:24.695
e3cdaa25-5f28-43c4-b1d6-de8ec2f95540	3293c2bf-4ceb-4e45-8597-61bad26a4bad	d0ec5d8029565c6f41e07d7ae67e7d5085e09f9170226d78e0c545d3491e50b1	\N	\N	\N	2026-06-12 06:33:10.969	\N	2026-05-13 06:33:10.971
be4c4e02-184f-4665-9ea5-9a488af0f6cd	ab32baa0-382d-48e5-a542-b6f6a3620a9b	946bc212946f6d94c8dd7df9ec27d0afd5a4eb89ca580de1f6c9741581465ca6	\N	\N	\N	2026-06-12 07:10:27.457	\N	2026-05-13 07:10:27.459
fc1f62bd-d805-4c46-aa01-de7a060b5369	90d6537e-9af8-48c1-8c44-acc1bac26dec	1257f9d89b53e241cdde81eb6492c3afa8c8f3e57ef3e564c70840e6c333167a	\N	\N	\N	2026-06-12 07:12:06.243	\N	2026-05-13 07:12:06.244
ec7311f0-90bf-4009-af9a-340a9cb86edf	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	1542eb47c4c7420aa2264b13ccbddb29d7dbd99b38010c5b0042a02d95390d06	\N	\N	\N	2026-06-12 07:16:09.116	\N	2026-05-13 07:16:09.117
54a277ca-c60c-4adc-936f-5d1039d46387	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	9ff3f084a9e7680eaf6b1afab503d8f890cb043a2e4fd30029e953252928b23d	\N	\N	\N	2026-06-12 07:50:58.513	\N	2026-05-13 07:50:58.517
4ad6f69a-8ab0-470a-b9d2-8f914d1d5bca	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	efdfe22b009e3a6b3ea71e2b55076f0dcea493fa8e3ac361952b30df6d924bef	\N	\N	\N	2026-06-12 08:10:26.673	\N	2026-05-13 08:10:26.675
ff96e4fa-15c7-4687-8b77-74d4613bdd80	90d6537e-9af8-48c1-8c44-acc1bac26dec	5d8fa6573838e5ff25ce428d9b3c91fab23d4736b8444d155520199e810d7703	\N	\N	\N	2026-06-12 08:13:35.101	\N	2026-05-13 08:13:35.102
5a505546-e0e7-42cf-9e9f-296fc37b0ecf	ab32baa0-382d-48e5-a542-b6f6a3620a9b	2dbd96cb95d94a91963b48dd1414e3c0239f0efd02b425b2497cf7e778fa17ca	\N	\N	\N	2026-06-12 08:15:26.31	\N	2026-05-13 08:15:26.311
41f35eea-f400-41cf-b83b-d5d38f71250f	ab32baa0-382d-48e5-a542-b6f6a3620a9b	44bda7630a3a2b22db69ab6cfaf2667e279eaf27e469399723c0a71746828fb7	\N	\N	\N	2026-06-12 09:31:53.064	\N	2026-05-13 09:31:53.067
b50998e2-5dad-4377-a62a-431b895a1bdf	90d6537e-9af8-48c1-8c44-acc1bac26dec	480bd0ee5f8b48c5b69159a39230bc09c13cc874fa240fbe72a53ef2a910eeb3	\N	\N	\N	2026-06-12 09:32:12.521	\N	2026-05-13 09:32:12.523
f77a3366-4067-44b9-86a2-ae3811463215	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	b85e2862a711195637a7f7fb6d3b87376ce6b7f5e9f356a097ba94923c808e8f	\N	\N	\N	2026-06-12 09:32:34.612	\N	2026-05-13 09:32:34.614
13397a33-8249-471e-8895-f39ee64ebe0b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	5eda3cd5e523b0bf3bedcfba9b97470c5922220f54a8b6e5f822d4b7536c3aa7	\N	\N	\N	2026-06-12 09:32:36.314	\N	2026-05-13 09:32:36.316
99f9e058-35c1-4b5a-8dd4-97a40ff65f79	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	64a9f1d603e2614e075c5bfa71b7b1b978692d7272e9d1e16ef8f2c2583319bd	\N	\N	\N	2026-06-12 09:32:37.365	\N	2026-05-13 09:32:37.367
d2c819e6-19c4-4ed3-bd72-73b9b13676c6	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	5e37917af7b5e604e03e1462052604e1685ed99b354080d66cacc9519c20fd45	\N	\N	\N	2026-06-12 09:32:42.306	\N	2026-05-13 09:32:42.307
98d28627-024e-45bf-93ac-ef8d212f7bcb	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	92ffbe86fecf8b83b50d0e24dfded9aff94f89ac3103e689834ae57e47f18139	\N	\N	\N	2026-06-12 09:32:43.175	\N	2026-05-13 09:32:43.177
b93a2a48-e603-4cbe-bc00-9d4479988c36	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	02f04197cbe73b09a272a2306e9569797f2b184a2eea03c114650eb23ee87b7d	\N	\N	\N	2026-06-12 09:32:43.761	\N	2026-05-13 09:32:43.763
05f81426-8fb0-47e9-96fa-5ba99190daad	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	30bb75624bbcd1f474d758cd2f0b74aeaceba9c48e09ef366025a0e6eecaafde	\N	\N	\N	2026-06-12 09:32:44.081	\N	2026-05-13 09:32:44.082
985d0908-f9e5-48fb-944b-f0a916b84b73	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	6a4167b000fe9603c21fc2e7a3025f0f43fea52f83e329f1b5a320e2f64b0cab	\N	\N	\N	2026-06-12 09:32:44.403	\N	2026-05-13 09:32:44.405
a9cbe200-fc59-438a-a674-6964483b2c73	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	e6f97bef1ddafeeb0a077a969ce5bd3f950c4d91aec167c91f4bf3d595e73dad	\N	\N	\N	2026-06-12 09:32:51.663	\N	2026-05-13 09:32:51.666
4f9da814-f37e-4e68-b818-5ab2e6986302	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	cc45724d6a4f3b87e3c952497c35f07de58687744ffc7b245f5c918e906b8e96	\N	\N	\N	2026-06-12 09:32:52.483	\N	2026-05-13 09:32:52.484
cccc82e7-443d-4397-aa35-7e9fcabd1527	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	dc1d4cd997c6f19166608685362221081fc9bd467200d35104d972cd57f58bc0	\N	\N	\N	2026-06-12 09:34:35.671	\N	2026-05-13 09:34:35.672
fde58ab4-c560-4f17-91e6-65f23ba38e63	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	81e0b5e760baa0e14c55913a5acb266b648c643505ea1273345e9e62c0dd7123	\N	\N	\N	2026-06-12 09:57:08.438	\N	2026-05-13 09:57:08.44
ee2e9084-b514-4bfa-8c92-4ad4ca3e02a4	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	57453344d47b8a2efb5bef0bb7eb4bef59530023ac7104cdc2076324dcbb36ba	\N	\N	\N	2026-06-12 09:57:40.32	\N	2026-05-13 09:57:40.322
9ece040c-8b45-4c1e-ac9e-efd99aafdbce	90d6537e-9af8-48c1-8c44-acc1bac26dec	3ac9f2710b43d87b5a38d913111de39f6c439a09e4bc40ba7fca22eb0c7eaf69	\N	\N	\N	2026-06-12 09:58:04.003	\N	2026-05-13 09:58:04.005
dedf90b2-cf9f-4b5c-843e-20cd1ed0ae95	ab32baa0-382d-48e5-a542-b6f6a3620a9b	3a3ae52ee3a25a0653e3792084a8de5e16ed40eafe1f5bb4565d67900e874e11	\N	\N	\N	2026-06-12 09:58:24.238	\N	2026-05-13 09:58:24.24
25197caf-fa8a-4b2c-b629-2e190031d3b3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	10d2a9f5940ef28cdb079e391d0bb4b8dcb8ce45a2c21fe28159461cb887f855	\N	\N	\N	2026-06-12 10:23:52.184	\N	2026-05-13 10:23:52.191
3ff87ce8-1642-4654-809b-3d435380f53b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	2ea7932eec65c3545278179fe8e9aeefb02353ab9376e74e0dae86389ba16cce	\N	\N	\N	2026-06-12 10:26:05.126	\N	2026-05-13 10:26:05.127
7a284e8c-96c4-40cb-a16c-66e3770c4d76	4e388ecf-b99c-4469-b8a9-51e355f9d4b9	670e65c39ed069acb5c2b54641c2ad2094cabf1a873c4126237110f6df7e06bd	\N	\N	\N	2026-06-12 10:27:36.23	\N	2026-05-13 10:27:36.231
0ff76604-67cf-4a14-9173-1b74cfa8c617	16cf4783-5c22-4ba9-9891-8a99774e5157	87a392b63b2b81c729e27bba7e5be0853b7d5e5080419e60ca9767733697abb2	\N	\N	\N	2026-06-12 10:42:00.83	\N	2026-05-13 10:42:00.833
01388040-0fd9-4fc7-85d2-a2d2ca0e0bad	90d6537e-9af8-48c1-8c44-acc1bac26dec	3164410cdacb1f599e1b0c508586f634109a3efe8d6e915e60f6c7c6e2156b74	\N	\N	\N	2026-06-12 10:42:59.107	\N	2026-05-13 10:42:59.109
341ea4f8-066c-45a9-b85a-98251ae70bab	90d6537e-9af8-48c1-8c44-acc1bac26dec	a70420f7a6d7e28d5ca27a8a85fcdbdfc0bbd8f5c552cca2c969ba9f55920a2d	\N	\N	\N	2026-06-13 05:05:39.094	\N	2026-05-14 05:05:39.098
003b93f4-db88-4bc4-a32f-a1c46466b731	ab32baa0-382d-48e5-a542-b6f6a3620a9b	eac1b92d43eb9b8a59be833fd72eedc48ee8735dc31b061610786a59b1e941c1	\N	\N	\N	2026-06-13 05:06:16.243	\N	2026-05-14 05:06:16.245
c54fce5a-4256-41ed-8dfc-5847d096c755	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	dae95b298f0265f5f9fbc4e6db7ed6323eaeb8987aa8734bcec36420728e2b02	\N	\N	\N	2026-06-13 05:07:26.941	\N	2026-05-14 05:07:26.943
bfc8bc96-d711-4d4e-a6e1-49804d598c7d	90d6537e-9af8-48c1-8c44-acc1bac26dec	8a85314b2884fabebe1ee070e79ce1742b2b53e671338f03c2bcaffacdb05d8b	\N	\N	\N	2026-06-13 07:26:37.446	\N	2026-05-14 07:26:37.451
f3d1d6d4-d7c8-4aa0-8296-d79142b6997a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	e53d4fd3c7b682d649fd480f2f13d4aaf113578672aa3487622c54ccc6b7fbdb	\N	\N	\N	2026-06-13 07:27:04.83	\N	2026-05-14 07:27:04.831
df40ea03-53cc-41fd-8f9c-95efb3929db1	ab32baa0-382d-48e5-a542-b6f6a3620a9b	4e7779fef2bcaf1111748db93f1343b6058366134e52f054e8c3d3329f4aa6a9	\N	\N	\N	2026-06-13 07:27:33.304	\N	2026-05-14 07:27:33.305
ff66c816-0e23-4f7a-98a3-1db963b15c14	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	01eb5e731458724559dc63650405b3132fadd6e0fd57333a06ecc99ecb342229	\N	\N	\N	2026-06-14 10:05:26.766	\N	2026-05-15 10:05:26.771
b5693c47-703e-4dbd-b1d1-59dc53031fec	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	015bfeccff99dcd5762b3b6bbe9744c88a6a2542a9d850c07406f5474c1af528	\N	\N	\N	2026-06-14 10:28:28.45	\N	2026-05-15 10:28:28.452
8e89163f-306f-4b3a-9e0a-c3d593049c18	90d6537e-9af8-48c1-8c44-acc1bac26dec	6205c81341e80761aeda3a57ec92653dec19adba93888b7a8c9341026e159b0d	\N	\N	\N	2026-06-14 10:51:18.935	\N	2026-05-15 10:51:18.937
1665bddc-efdd-473a-b2f2-b16afcc0d620	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	d677aa2b97a01a360f879349152920e42fb006129dafa7a9bafa56eb189d4e94	\N	\N	\N	2026-06-14 10:51:45.901	\N	2026-05-15 10:51:45.903
4b9c5310-362a-4143-b658-bcdbb9bab1fc	90d6537e-9af8-48c1-8c44-acc1bac26dec	9dfe8e5a7c44c93ca9617cdce0e3493734f500f7e33c0227a426957899315aee	\N	\N	\N	2026-06-14 11:11:07.239	\N	2026-05-15 11:11:07.243
401c9758-1d1d-4471-a8df-8a0a00b60a19	90d6537e-9af8-48c1-8c44-acc1bac26dec	1083305797d015fa5ff5d022c1c13615dc13066a1bbd358f25101a8bbc1aab4d	\N	\N	\N	2026-06-14 15:00:26.169	\N	2026-05-15 15:00:26.172
2b1fa709-b987-419c-8641-c664890eb536	90d6537e-9af8-48c1-8c44-acc1bac26dec	f3961dda8f814322d53680fd756c52376bf6cd2d95dd1b8230752010853910ed	\N	\N	\N	2026-06-14 15:22:15.438	\N	2026-05-15 15:22:15.442
e3326813-1083-451a-ac02-c013e40fafea	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	8042b5fbdb4bc1fa73e5cf0ddad734d0b0ed44ceb76b3a94da31c3bd23951f59	\N	\N	\N	2026-06-14 15:23:50.632	\N	2026-05-15 15:23:50.634
7042b4bc-773b-4168-a646-af7dd8a60ada	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	a206a8ae1f62deaf5bbf6cbf5a8c3685272fc5b394f1d894f2fc1df536170ec7	\N	\N	\N	2026-06-14 15:30:32.126	\N	2026-05-15 15:30:32.129
c868025b-912b-42b1-bd12-0115b114ed9c	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	9297ee6b79a4a82f8d4b86c3618c1353e0c6a07afd4a00e28f5fe03218e299a9	\N	\N	\N	2026-06-14 15:30:32.425	\N	2026-05-15 15:30:32.427
45222fe0-a8b6-4724-bd7e-c98c3b14783b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	80ceef1cf76280df409c68668d1c0f7d3049c8d1f85ad475d727428e0b4cd039	\N	\N	\N	2026-06-14 15:41:59.654	\N	2026-05-15 15:41:59.657
0f88c215-599f-4a41-9a4f-7606fbdbc864	90d6537e-9af8-48c1-8c44-acc1bac26dec	4ed5b546950df8ca967e8bee452ec8efe62b953ccfa15a301d327b49f11336f9	\N	\N	\N	2026-06-14 15:42:08.132	\N	2026-05-15 15:42:08.134
1806bf83-a9e5-4b25-b7a6-517a33b883b1	90d6537e-9af8-48c1-8c44-acc1bac26dec	0fa8153b88969e6f9014b32a078dfdc2197ea69a07e18af604cc24f772c667c7	\N	\N	\N	2026-06-14 15:42:16.309	\N	2026-05-15 15:42:16.31
bf377f4a-5462-4df0-b86f-14677e5a0da6	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	149a7960f484cac1bfb9a7bd68b5a63644947779d8cd3a050da235ee93fe93ea	\N	\N	\N	2026-06-14 15:53:53.376	\N	2026-05-15 15:53:53.378
a06d9fbc-9a2a-44b6-b240-3ff6975a3889	90d6537e-9af8-48c1-8c44-acc1bac26dec	610fb2fb7c6daab3ea43f48addd3b0509514c616dad9ea46c96cc2ba852c888f	\N	\N	\N	2026-06-14 16:17:18.415	\N	2026-05-15 16:17:18.416
ce2cf6ce-730b-41cd-9d67-6229d1ca1c45	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	e040d0c2c84556d6e8edf7833d2b9a40704b83bf05716f02e1193a6d9793dbad	\N	\N	\N	2026-06-16 08:43:20.597	\N	2026-05-17 08:43:20.599
aa6b476d-e428-4d71-8da2-daa8c3e73f7e	90d6537e-9af8-48c1-8c44-acc1bac26dec	62b849e8e9b9f126c6ad95e9ba8e02d87f38bfd3bcc0fa6b63766f39ea994ca1	\N	\N	\N	2026-06-16 08:43:21.008	\N	2026-05-17 08:43:21.009
7dea7be6-3026-4e4c-9230-da297ddb8ceb	90d6537e-9af8-48c1-8c44-acc1bac26dec	76cfe59fbe3e0014389df0dfab2d6d122521c2d5696f143376468c4559a90ea8	\N	\N	\N	2026-06-16 08:58:15.019	\N	2026-05-17 08:58:15.021
079269b3-d898-450b-a9d5-275334462d8a	90d6537e-9af8-48c1-8c44-acc1bac26dec	aa6fc8ad38acf82997cab9d85b8d54de87da72a299265d0e596ebc03156b290d	\N	\N	\N	2026-06-16 08:58:25.384	\N	2026-05-17 08:58:25.386
83f77893-66bb-44a2-9532-8e49e55f0827	90d6537e-9af8-48c1-8c44-acc1bac26dec	94de72a5e9ab98557b3bb9b984c823478cfc365a550b8173bf64d8f25bc32319	\N	\N	\N	2026-06-16 09:08:21.522	\N	2026-05-17 09:08:21.524
b5108aa2-05b9-4027-aaaf-2b683966bc0a	90d6537e-9af8-48c1-8c44-acc1bac26dec	ccdeb28b4130dbfd5511abf8751802998d259217ffa5ad151ebc95a6378408ec	\N	\N	\N	2026-06-16 09:08:33.115	\N	2026-05-17 09:08:33.117
ad185006-7dc6-4288-be2f-3282fee902ec	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	bb18e23e1f8a1b8971a71acff9c3e48113a2d0223b73905eac2818c954b1103a	\N	\N	\N	2026-06-16 09:08:33.653	\N	2026-05-17 09:08:33.655
00b1b366-d312-42ac-af41-8f9468fe52ce	90d6537e-9af8-48c1-8c44-acc1bac26dec	4636a030c0279e5f2a66ed03b756a4dc79fbfa27b7d6ea5769839249408fb8e7	\N	\N	\N	2026-06-16 09:08:42.671	\N	2026-05-17 09:08:42.673
adcb3cf7-5e81-4462-a296-2dabff9bcf4a	aedd04e8-4140-437f-b66b-0f133c42b11f	4f794f7538f0d2d0150a6253d0a43c2537792afa72478007a0fccff49eedec23	\N	\N	\N	2026-06-16 10:23:11.383	\N	2026-05-17 10:23:11.385
b4dde000-d17a-4401-9456-a2c643bcea0e	90d6537e-9af8-48c1-8c44-acc1bac26dec	740d23fc1c32f7d2bebdea4d0f9e7478b1960787dc71961c36414817fbf78cf7	\N	\N	\N	2026-06-16 10:24:12.326	\N	2026-05-17 10:24:12.328
c2e42d40-52fc-44a7-8c37-60ee5c1e397b	90d6537e-9af8-48c1-8c44-acc1bac26dec	9d52a1d3e472fdd0a5bbb2de6687afb3ad41dc44c56fc90527b02743cdb388d6	\N	\N	\N	2026-06-17 04:59:43.32	\N	2026-05-18 04:59:43.323
75a9a5da-bac7-4914-aff8-67f87e313e68	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	c28b29aa1722d0895c8017a0f9eb3276951078a0822cfb333b512112660de385	\N	\N	\N	2026-06-17 06:55:33.357	\N	2026-05-18 06:55:33.359
ae3892d9-f2e8-4482-b9f6-0ad9d7b28c09	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	ff63ce0d9511e99b286bff5ae3e73ddbfba538eb72274cacf6fe5d9ecf3c5eea	\N	\N	\N	2026-06-17 08:38:44.938	\N	2026-05-18 08:38:44.939
d6bf503d-c271-4c01-b93c-b7c195c9d4f8	ab32baa0-382d-48e5-a542-b6f6a3620a9b	838cfdd04decc185962e3d69f405bd1587180ce1163319c25fa129b89678f8a8	\N	\N	\N	2026-06-17 09:01:19.028	\N	2026-05-18 09:01:19.03
215667d0-33d9-480e-bc8f-b4bd637f13e0	90d6537e-9af8-48c1-8c44-acc1bac26dec	8708dbe4a60871e5cfc685aab2a90af6b89ef3b4df1340e0672dcf19c66a206f	\N	\N	\N	2026-06-17 09:02:02.591	\N	2026-05-18 09:02:02.594
0aad509b-3dca-4c44-8bbb-6838cb6459d8	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	406130cde32ae3acafe44da697afc199ec0b560d614c1d3797d93170a5664bc0	\N	\N	\N	2026-06-17 11:10:21.247	\N	2026-05-18 11:10:21.253
f04107ea-6db5-4792-99e7-4eff30541a79	aedd04e8-4140-437f-b66b-0f133c42b11f	d67ec398857ce30dc582afe227767d80615c42422320f669b07ed08bbfaf0b99	\N	\N	\N	2026-06-17 11:29:15.368	\N	2026-05-18 11:29:15.371
34ea4d90-c849-463d-86ea-4f4f98046b71	7858ce6f-8e76-41a7-8389-296144e78f8f	bd0c51b711ace37cf5c40e775fc3fbbc987b2c6df3897121b4efb5ce35588520	\N	\N	\N	2026-06-17 11:29:28.803	\N	2026-05-18 11:29:28.805
8e00bc85-5c71-4c13-9d9e-6c96f85f24f1	aedd04e8-4140-437f-b66b-0f133c42b11f	e434016e7aa281402ac753344d540fecf17522ed1394855b90411c259062c9b5	\N	\N	\N	2026-06-17 11:29:29.053	\N	2026-05-18 11:29:29.054
5c881b66-d326-4628-83a2-113c3ca3ab07	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	2dbdb46ed59a187c95fe40364918391c5044a8d74864ec035579570de1085087	\N	\N	\N	2026-06-17 11:29:29.407	\N	2026-05-18 11:29:29.409
83b74361-6250-4dd2-92b8-e6c763424072	90d6537e-9af8-48c1-8c44-acc1bac26dec	8793e40713ee2ba4da764a2c15d685aff01a4aa49d91b57d1050039eb103b395	\N	\N	\N	2026-06-17 13:14:10.977	\N	2026-05-18 13:14:10.979
8ddb56e2-7be5-44d4-a7e7-d6eaf8df2fe3	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	487df451ce341f294e4093ecb0c3ba755d55d946194c1153ea6a253bbaad5deb	\N	\N	\N	2026-06-17 13:52:16.401	\N	2026-05-18 13:52:16.402
d832af04-2df7-4f65-8a18-4530bf39497c	90d6537e-9af8-48c1-8c44-acc1bac26dec	bfb6f8f15e40e6e4150d006fe64728e9ab0cafc3477d64007ab5c40b881d310b	\N	\N	\N	2026-06-17 13:52:16.645	\N	2026-05-18 13:52:16.646
60a79e7e-3e24-4a54-aac5-a0d95e151b1c	ab32baa0-382d-48e5-a542-b6f6a3620a9b	b2909d2bc7b59825ab97ae8a254240791be04bd1e948e1a93bc348bd108dfc06	\N	\N	\N	2026-06-17 13:52:16.887	\N	2026-05-18 13:52:16.888
caf8b713-a8ad-4499-901e-a75a92a9e0d3	aedd04e8-4140-437f-b66b-0f133c42b11f	763a11f7768db1252d5c7f8eaf2d7f4247a4fb4dd55b3525abc7f2ea82d59153	\N	\N	\N	2026-06-17 13:52:17.229	\N	2026-05-18 13:52:17.23
ce8fa302-b5fd-4de4-9635-1eab85be4ab4	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	2ec30a16e49ea1dbada38d2a12512b4d74d683efcf80850e79f763972413f469	\N	\N	\N	2026-06-17 13:58:12.72	\N	2026-05-18 13:58:12.722
440c4b15-9973-4903-b3cc-97f7c686d9cc	aedd04e8-4140-437f-b66b-0f133c42b11f	fcef47f4647047405436443793cd5185f053a9e7845c18a4e8b47505fbdabaac	\N	\N	\N	2026-06-17 14:29:33.338	\N	2026-05-18 14:29:33.339
f4af9ed2-00ff-4a43-88d3-14356ecf2ee4	90d6537e-9af8-48c1-8c44-acc1bac26dec	4a02b29b6e23c7b6d0b19f20cdf961318aa23683afe2ae7ea1261969d201ce44	\N	\N	\N	2026-06-17 14:31:40.731	\N	2026-05-18 14:31:40.733
ab503ba9-d221-4555-995e-c704b5192034	aedd04e8-4140-437f-b66b-0f133c42b11f	a341f96e569f5627bffe763931c40ef8a38f61a57a19d6dc3dd3de472fd243a5	\N	\N	\N	2026-06-17 14:31:41.026	\N	2026-05-18 14:31:41.027
5c9da15f-6735-4589-84f0-63bc891370c1	90d6537e-9af8-48c1-8c44-acc1bac26dec	0881a4c98da6918c01f892edc30ba76fce5cf4167ee281faf6416f16a5d64b51	\N	\N	\N	2026-06-17 14:32:01.749	\N	2026-05-18 14:32:01.751
42acf525-7fa2-4864-a77b-1f4ae68af959	90d6537e-9af8-48c1-8c44-acc1bac26dec	be1bb6a4e4358ea58619b6a8203f1eb24bc3166735475eacb01d14eef00c2389	\N	\N	\N	2026-06-17 14:32:25.536	\N	2026-05-18 14:32:25.538
bf249ac5-7d6d-4184-8502-a6b4162dab9d	aedd04e8-4140-437f-b66b-0f133c42b11f	e73a9545629f0453b6ac87bb11fe92c20b63880022394ff2332b165d54be3eeb	\N	\N	\N	2026-06-17 14:35:00.719	\N	2026-05-18 14:35:00.721
0487fc22-c3dc-4d45-82d3-086fcac382da	90d6537e-9af8-48c1-8c44-acc1bac26dec	1f26eb0c4fce41a3a9202a109fc71314a2231758fa1d245544955c8745e12831	\N	\N	\N	2026-06-17 14:35:14.197	\N	2026-05-18 14:35:14.199
43a33ad7-9d8d-4cac-a287-a9bef75665cc	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	cb1ccce08e06b1c125ff326d182d6a010b2878ad858804f1e28cc05cf1420e8f	\N	\N	\N	2026-06-17 14:35:37.854	\N	2026-05-18 14:35:37.856
a8fa5680-b4bc-454a-af13-e46174b8d303	90d6537e-9af8-48c1-8c44-acc1bac26dec	3c9fe4cc9766512846ad26ed0af93a80ea87dbb20d66d29186f9d4209a35d066	\N	\N	\N	2026-06-17 14:35:38.091	\N	2026-05-18 14:35:38.093
80886b1d-8c69-4fd9-9253-1b9377910f12	ab32baa0-382d-48e5-a542-b6f6a3620a9b	85953cf49951595d27ae8d735bcefa785bc9c42a33cf81e3d0413173fe4972f6	\N	\N	\N	2026-06-17 14:35:38.294	\N	2026-05-18 14:35:38.296
837b911d-e372-419c-abd3-9108bd681a1c	aedd04e8-4140-437f-b66b-0f133c42b11f	dde89544498014e02e8d3277994ee1692bdd447333b1db19f8673c99f1a5a8b9	\N	\N	\N	2026-06-17 14:35:38.538	\N	2026-05-18 14:35:38.539
bc219e6e-6d6c-44a8-8434-1eaa816e9d08	aedd04e8-4140-437f-b66b-0f133c42b11f	24575ee26d0f1f2f236465d85839195d2ff8c8278905fb59e8bb8ba3e36db4e3	\N	\N	\N	2026-06-17 14:46:13.486	\N	2026-05-18 14:46:13.487
ea20c4d6-3272-4cf2-bec1-5a54e2d9881f	90d6537e-9af8-48c1-8c44-acc1bac26dec	634217b5e5479f8146612edf612417b57865377b91e258a3848248ccc30ecabc	\N	\N	\N	2026-06-17 14:47:46.698	\N	2026-05-18 14:47:46.699
e017808f-3bce-4ffd-9d6f-087f8a71e5bf	90d6537e-9af8-48c1-8c44-acc1bac26dec	31e1c46cbbabea0bc550e5156ea809813c79e5bb5e43dd0142c02b1f61d8c698	\N	\N	\N	2026-06-17 14:48:30.672	\N	2026-05-18 14:48:30.673
04b3fd3d-71a3-4098-bd0d-670f9941cb68	90d6537e-9af8-48c1-8c44-acc1bac26dec	e0ffd50e392f0b1ec5fbb3f2224b28e3209c21c1ec300edf44bf7a593574cc23	\N	\N	\N	2026-06-17 14:50:01.364	\N	2026-05-18 14:50:01.365
7d18e3f1-92bc-4392-99f6-39867c637919	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	456bb9d56d7c11acdd579d40d2a45d72ca23c2f7b02d1f0829ea749b737a0143	\N	\N	\N	2026-06-17 15:02:01.675	\N	2026-05-18 15:02:01.68
56b62320-6648-4a74-8139-76d2e2faf421	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	ab9d4d4680ae8a508291366db219665bc4b5a0e574767d486b4c43e1ad1052dc	\N	\N	\N	2026-06-17 15:29:30.515	\N	2026-05-18 15:29:30.517
71326ab7-80b4-4705-a909-13d41c750205	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	4a8afa1004ad14233ded7ac9bc1dc8aa34b0266bd289914a1af758ed8e80f6bc	\N	\N	\N	2026-06-17 15:33:59.481	\N	2026-05-18 15:33:59.484
9a26273c-7bd4-4868-ae54-62ae7ccb72a7	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	abaff7b19fb82a070b665778cf6f74d13ab9159c2de8222669a82ef54d3a88eb	\N	\N	\N	2026-06-17 15:34:11.525	\N	2026-05-18 15:34:11.527
c52662fd-8c0d-48c3-8af2-8f87f6174d0c	90d6537e-9af8-48c1-8c44-acc1bac26dec	074ddfe890d90140a125f8ab2d40efa52299a57817aeafb9224fdef446ccf5b1	\N	\N	\N	2026-06-17 15:34:11.713	\N	2026-05-18 15:34:11.715
123b2c0b-67a9-4877-abf0-c8004deb5d2c	ab32baa0-382d-48e5-a542-b6f6a3620a9b	0d488661822a3fada670559116b42633f47f326713428dd4cfe4f44609f8f0f1	\N	\N	\N	2026-06-17 15:34:11.994	\N	2026-05-18 15:34:11.996
9f5fdca0-b6ef-4bff-ac1f-cb0ec60fe006	aedd04e8-4140-437f-b66b-0f133c42b11f	721274fc71c56f104ea545abc19744656e563fd5bc780452946d6e438c1c0680	\N	\N	\N	2026-06-17 15:34:12.209	\N	2026-05-18 15:34:12.21
507b404c-d7b7-4ca3-88fe-e3ccd2721b40	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	7ca2374664b45193d9f7329cbf2520457ab9d4275f109a48144ac3278385c3b6	\N	\N	\N	2026-06-17 15:45:55.02	\N	2026-05-18 15:45:55.022
0593d4bf-19db-4f07-9a1b-26bebd9cdff1	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	6738601ef4198a79f33e8a4712c9330e03e658adf430084cb41197b5f88e2cf5	\N	\N	\N	2026-06-18 08:45:31.861	\N	2026-05-19 08:45:31.864
8f6125f1-fa13-4628-9380-02b13208ce77	90d6537e-9af8-48c1-8c44-acc1bac26dec	fc4719bbc0c65172d5b5fce0a74884469c739deba7a90425e33a27edd59feccc	\N	\N	\N	2026-06-19 08:44:58.454	\N	2026-05-20 08:44:58.456
51394833-edb6-482f-a5bd-a7e88f5418c3	aedd04e8-4140-437f-b66b-0f133c42b11f	cff8a8410f77405693f0b2bbf8047b6af74b6caf1e5423538823a5dc576f633f	\N	\N	\N	2026-06-19 09:00:41.477	\N	2026-05-20 09:00:41.478
0b7b7bde-64f6-4ec7-8216-5377d2a51e32	90d6537e-9af8-48c1-8c44-acc1bac26dec	b9f530e52f79d2da4b7a442388ddfa54e7ac467af961f50793e103db3a860c3c	\N	\N	\N	2026-06-19 09:32:59.009	\N	2026-05-20 09:32:59.011
bc301ae3-5522-444a-9332-9c54c97f125d	aedd04e8-4140-437f-b66b-0f133c42b11f	7837370fd982411934a6695670bc11f3e7957fcad882d4b460dbdd713684ae9e	\N	\N	\N	2026-06-19 09:33:43.184	\N	2026-05-20 09:33:43.185
d9ed5c03-84c6-4263-9df2-b2f1ab7cd8a2	90d6537e-9af8-48c1-8c44-acc1bac26dec	e52f95d2c028c3e03025b03515b7c8d3a5a1d42bde806a836a81801e8d54146f	\N	\N	\N	2026-06-19 10:12:28.453	\N	2026-05-20 10:12:28.454
3230f5dd-3892-48fa-bef9-1d4cf7e2f5c7	90d6537e-9af8-48c1-8c44-acc1bac26dec	785e608f98f154b0b8201a8a5063a48f10064352a655531030fc10100ab064ef	\N	\N	\N	2026-06-19 10:12:45.805	\N	2026-05-20 10:12:45.806
c55db48f-4bde-449d-a644-7a10d130c3ff	aedd04e8-4140-437f-b66b-0f133c42b11f	5f7927762426c275353f0ba71e681f4533a19e4701ffe2e1722852a2fd6df0fd	\N	\N	\N	2026-06-19 10:16:07.629	\N	2026-05-20 10:16:07.631
d9e01484-a559-4c81-b309-6521891f58c7	90d6537e-9af8-48c1-8c44-acc1bac26dec	98cd95f43e5673014fd19161940167c8d2120b454f80d513241e2d727b594999	\N	\N	\N	2026-06-19 10:16:23.903	\N	2026-05-20 10:16:23.905
af1f85f1-e5f3-46b5-81d6-98cec9cc2733	90d6537e-9af8-48c1-8c44-acc1bac26dec	8071675cb7befdaab604f821d50dbc71087c340760acee6c59eca79a21785b54	\N	\N	\N	2026-06-19 10:30:54.452	\N	2026-05-20 10:30:54.454
f1587873-7d85-4e57-ae97-dd1540f8e09c	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	ff88b1df8c75b87c4295228908a71997f93148c89f78f98fbdbfba8c0387b989	\N	\N	\N	2026-06-19 10:54:18.784	\N	2026-05-20 10:54:18.79
392d4f44-9d62-48e7-9a88-82be723ac6ff	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	efe508127eb1da7da41f6871161f7eaa8cdc17af376dad5f0585c086aafd4a55	\N	\N	\N	2026-06-19 11:06:25.665	\N	2026-05-20 11:06:25.667
3d7a11db-08fe-4e5e-954f-7798bfb3d7b9	aedd04e8-4140-437f-b66b-0f133c42b11f	105cf16484eaf5c5ee3b5ebbd80dbbc84db1279addc7d62be203b55fa8408507	\N	\N	\N	2026-06-19 11:19:45.002	\N	2026-05-20 11:19:45.004
37a80f4e-3861-4955-a490-de1b772d8973	aedd04e8-4140-437f-b66b-0f133c42b11f	6dd5fadeda30f5fbfac81f8244fa3951239e86d5be3fd1a90ecc3eead8270f88	\N	\N	\N	2026-06-19 11:20:24.33	\N	2026-05-20 11:20:24.331
6ff6ad47-d3e8-49c8-b840-e5b3d28ac543	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	de862a731eab10a5e2befb3a1a47f26d4e2193dbd1c5ef02b5d4218bc9cad4cc	\N	\N	\N	2026-06-19 11:23:38.621	\N	2026-05-20 11:23:38.625
6035bce8-3e10-439a-9d35-fa5589717586	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	3066668a3ad2276a617620280d16eadccb74ab9d09344be3016ddc1cf1cb0849	\N	\N	\N	2026-06-19 11:44:22.58	\N	2026-05-20 11:44:22.583
fe680283-ee98-48f9-a6a0-0ce4643720e7	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	b041d17df7d83c7defc0aa873a7e93cd67b048917157db16404880840b82f1c2	\N	\N	\N	2026-06-19 12:12:52.326	\N	2026-05-20 12:12:52.328
a493f4ff-3279-49ff-92ca-aeb66ebc569e	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	af9cf7fcd7adca9509a6a9cdbf95bfbb01be486a8ba1e679c386e79186d9b67f	\N	\N	\N	2026-06-25 15:40:16.308	\N	2026-05-26 15:40:16.312
2ed8f4a4-12b2-4dde-83c0-5d4a2a6aad59	aedd04e8-4140-437f-b66b-0f133c42b11f	9ed71ee09dab1757841b243f160af36017f3f52bb0a4a319b216aa138e132fff	\N	\N	\N	2026-06-25 15:54:17.104	\N	2026-05-26 15:54:17.106
a76b2ade-5398-49bf-8b38-d663ed92ca99	90d6537e-9af8-48c1-8c44-acc1bac26dec	873b9a5e7e1821a8574d97d30d680fb8a32af800b4ba67556e86c4ceecdb6fa7	\N	\N	\N	2026-06-25 16:03:22.858	\N	2026-05-26 16:03:22.86
1c165fd9-da00-477a-ba8b-8e23c9e74f01	aedd04e8-4140-437f-b66b-0f133c42b11f	62aadbc900f77692dad8585f8875c279144a07389b5e2693ff54efc6bb0102fa	\N	\N	\N	2026-06-25 16:42:45.283	\N	2026-05-26 16:42:45.285
a43da146-6ca9-4a06-b407-1d43cea2666f	90d6537e-9af8-48c1-8c44-acc1bac26dec	146b41f6f0b59658f04ae5180f9eab8b51cb65b6d6175f0925c012c2d4222592	\N	\N	\N	2026-06-26 01:42:46.998	\N	2026-05-27 01:42:46.999
5aff2e99-9f2f-498f-a361-f13ba68c3c73	ab32baa0-382d-48e5-a542-b6f6a3620a9b	3422c05b294aeaa065ad8f4269d3147c96621cdb124e656a2607aece4fc0180d	\N	\N	\N	2026-06-26 01:43:37.364	\N	2026-05-27 01:43:37.365
01eeba7d-bf0c-4ce8-8078-3a976da1c24f	aedd04e8-4140-437f-b66b-0f133c42b11f	ff6452baffc64e17e81e46fa5f3000970e4eafbfd77de8604acb4c6811b2cd21	\N	\N	\N	2026-06-26 02:13:09.369	\N	2026-05-27 02:13:09.371
df57835a-f45b-4875-91e0-ee599cb4f533	aedd04e8-4140-437f-b66b-0f133c42b11f	d5cbaaaa7f791aa2fabb996114f888dde3393aed64393f47e332f98a3bfcc365	\N	\N	\N	2026-06-26 02:19:39.123	\N	2026-05-27 02:19:39.125
0c078976-a6be-440b-adab-8d810417385b	aedd04e8-4140-437f-b66b-0f133c42b11f	2ede5638adb75bf05be43488b3f6cb1c94e3e078057d4b1c9ca47f54d5780cc6	\N	\N	\N	2026-06-26 02:19:59.01	\N	2026-05-27 02:19:59.013
d6130745-5535-40da-bcad-c7ca6fe13ab0	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	7cfc21244471bcb8ecfb304038b1084cbcce63f17173da1fbfa0849d4bbb94de	\N	\N	\N	2026-06-26 04:41:18.977	\N	2026-05-27 04:41:18.98
497c905f-200d-4f43-883a-a1b62540489b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	cc8ab82d89ccb972c58e234ec25740b4a0239356ccef8923115198fcb41fc434	\N	\N	\N	2026-06-26 04:42:54.374	\N	2026-05-27 04:42:54.376
2a30293e-1e79-4d14-af93-d2e3a2992d7f	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	dfd4c2d5a7afe7dfcb6249f1240ecaf355e2958109673d09695590210c6cd5f9	\N	\N	\N	2026-06-26 04:43:33.812	\N	2026-05-27 04:43:33.814
17c436fa-03fa-4a5d-bced-b8aeeb1afdf7	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	e97db4e5b5f18b1f5022c9533bd2deb2fecba049ed3522af28c6d91fd893c398	\N	\N	\N	2026-06-26 04:43:48.559	\N	2026-05-27 04:43:48.561
19564dd6-9826-4be8-9af8-c114d8904dd2	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	5739b44dc934363a0ed922ac31fb5df476cb5954dbd8a62ed73db2f6321744c9	\N	\N	\N	2026-06-26 04:44:26.524	\N	2026-05-27 04:44:26.528
d163ae9d-de39-4c6e-aa58-200d299c4960	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	9c891bd1daf4dbd9d3721c301cf7b4b017429497035cb611403df2f08f5b7e04	\N	\N	\N	2026-06-26 04:45:32.374	\N	2026-05-27 04:45:32.377
c750b6af-94c1-4fda-be64-c783b3b1bf0f	aedd04e8-4140-437f-b66b-0f133c42b11f	73e76638b81e876c778ef145b2ea36984f65aa581f2ea52b7610fded4f641202	\N	\N	\N	2026-06-26 04:45:47.549	\N	2026-05-27 04:45:47.551
99205661-0f81-40c6-a5bb-51fe6abfa37a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	f07c92adca732b091c823e068e924e8aa4a30e8aa68a733af7da3c352f7c085c	\N	\N	\N	2026-06-26 06:23:27.107	\N	2026-05-27 06:23:27.117
d68a4a54-f592-49ac-805d-0c6d673e44d8	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	551c6476d0525d4759a46f1b0eeca068773397611d0c19cd7330b358706675fa	\N	\N	\N	2026-06-26 06:23:56.855	\N	2026-05-27 06:23:56.862
039f526c-cc8d-406b-a5e4-3806338c0f97	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	f9a060c4fbe22c78d78ce1ec2c915c0421d2ee24a247318962ed8df7bf969176	\N	\N	\N	2026-06-26 06:41:34.449	\N	2026-05-27 06:41:34.452
588c8766-977e-4d9a-b9fb-6654f710b0e4	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	f03eddd0cd5040563eb4fd815e1cddbd2dacb4a2ddadb8f69e507a6485263bd1	\N	\N	\N	2026-06-26 06:41:47.108	\N	2026-05-27 06:41:47.11
6d4e35e1-041e-4feb-94c5-2e83cabc3311	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	2bbb1a66a7c84fa9b991039eaa2ad61ae3207fda39bbb0fbf6a2a35847aa94e2	\N	\N	\N	2026-06-26 07:06:41.855	\N	2026-05-27 07:06:41.856
5073d0b1-87d2-459c-a794-9ed69e910e1f	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	e18f55dfa30e9cb930e097230f4fb7e2a536b5a4e2eda5643fd7b004d86d43cc	\N	\N	\N	2026-06-26 07:06:51.66	\N	2026-05-27 07:06:51.662
c4effba9-478c-446f-aed3-32651bf51034	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	545e0f77300271a255cfa411db146fcd266f451f34f246c6c2b46a8a60cd7f2c	\N	\N	\N	2026-06-26 07:07:05.421	\N	2026-05-27 07:07:05.423
faf1e34d-a31a-4add-a3f1-d86fc2d5208d	90d6537e-9af8-48c1-8c44-acc1bac26dec	948df7c1318db4b60c74a026ac7c1e3750cc73c37c9d0cfd9fdf635e0150278c	\N	\N	\N	2026-06-26 07:18:55.867	\N	2026-05-27 07:18:55.869
697dc0f6-42ee-4230-b5f7-a7d393d12591	aedd04e8-4140-437f-b66b-0f133c42b11f	e24686d3802f994da95630c028b16b149d32b5dd652d71ff394eb3d32562e61c	\N	\N	\N	2026-06-27 08:08:20.714	\N	2026-05-28 08:08:20.716
1f200c95-9f99-472f-a35e-aa1251a5d1bb	90d6537e-9af8-48c1-8c44-acc1bac26dec	75e1231336a5cb41a213cc54afbba8864646172112d33e86fb3156d91aa4ece8	\N	\N	\N	2026-06-27 08:13:49.639	\N	2026-05-28 08:13:49.64
7ccd077c-2e1f-4def-b620-7f91a6d07b0c	90d6537e-9af8-48c1-8c44-acc1bac26dec	c0e6b2f6432a51dd4788b5cdb52256a34ab1b25b6dc56da2798f147ac7b6b7c6	\N	\N	\N	2026-06-27 08:14:56.787	\N	2026-05-28 08:14:56.788
6653dcac-3600-44a2-8430-6fd407c719b2	90d6537e-9af8-48c1-8c44-acc1bac26dec	deb9776cada1ba67a3c4719a1008600323b69d49761d0a37a0b1065dd7efb1d2	\N	\N	\N	2026-06-27 08:15:30.985	\N	2026-05-28 08:15:30.986
349ee201-79dd-4663-9913-3f5ea76b83ae	aedd04e8-4140-437f-b66b-0f133c42b11f	196d03c346cd3dc272b3f7941d22089d09b651d84d571a507899fa8a6beb3c67	\N	\N	\N	2026-06-27 08:15:49.887	\N	2026-05-28 08:15:49.888
8cb0ee06-1f72-475d-a516-3090117fa711	90d6537e-9af8-48c1-8c44-acc1bac26dec	98d5bb789240155beeaa677f41819ed628f3f4b84491862311db6e2adee63f5b	\N	\N	\N	2026-06-27 08:16:03.831	\N	2026-05-28 08:16:03.832
977df7e6-075b-453b-bfa8-caeb8cc30813	aedd04e8-4140-437f-b66b-0f133c42b11f	1aa376df2d6e8677a80574240c8741c099da9d074fa03d7bc54ff14cf6416216	\N	\N	\N	2026-06-27 08:24:55.864	\N	2026-05-28 08:24:55.866
f5d61af7-01ea-4661-a019-fbc744ac989e	aedd04e8-4140-437f-b66b-0f133c42b11f	372c36466d71feccf88751dcfc1f42e03733a73e0041136a7eff522d863dda54	\N	\N	\N	2026-06-27 08:25:11.296	\N	2026-05-28 08:25:11.297
9485e03d-e946-4d25-9125-7a18e851c92a	aedd04e8-4140-437f-b66b-0f133c42b11f	ddeef5fdee10bd142ffaebc89f86da26f866af61f4d48bdd743120ac53bda858	\N	\N	\N	2026-06-27 08:49:20.92	\N	2026-05-28 08:49:20.922
22574677-37ed-47a5-a8b2-f3de1d18368e	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	2166eea0b924e3496ccbd0f4586883f6d55dd854833a8ca901b5b5a468ebfd49	\N	\N	\N	2026-06-27 08:49:56.711	\N	2026-05-28 08:49:56.713
812c433f-77bb-4417-81c9-09bd56230837	90d6537e-9af8-48c1-8c44-acc1bac26dec	8317119f879d131428b4aa9c2625e9a498f378d9c9ffd4238203db76b3108b6c	\N	\N	\N	2026-06-27 08:52:06.975	\N	2026-05-28 08:52:06.978
ef537362-c171-4fbf-8a61-e7b79298cd09	ab32baa0-382d-48e5-a542-b6f6a3620a9b	85d77fedcd9ce62bbe44fb3d49b3fbf609a6238a1b26700580b136586f73b829	\N	\N	\N	2026-06-27 08:53:45.824	\N	2026-05-28 08:53:45.825
a2db8e17-3062-476d-af97-e055194920f2	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	c003bcb94e9440a98124e2f5bb7fe8c55086c098d38d354b04edcfaf43c3267f	\N	\N	\N	2026-06-27 10:33:48.938	\N	2026-05-28 10:33:48.94
24652010-b5f3-4f09-b994-ccf088fd54e0	90d6537e-9af8-48c1-8c44-acc1bac26dec	a285dfe5c2bf212fffe55bdcb8396d809e534d3caddb73ed03753bff178fde39	\N	\N	\N	2026-06-27 10:33:49.214	\N	2026-05-28 10:33:49.216
1881f320-ef83-4aa6-beeb-815a2211425c	aedd04e8-4140-437f-b66b-0f133c42b11f	efe0062cf9d49d41d45eaac74345a757f491146babd45db6c3606a7ea1341ad9	\N	\N	\N	2026-06-27 10:33:49.461	\N	2026-05-28 10:33:49.463
7cfd7089-951a-4ff1-aa2b-8a1e6a25f428	ab32baa0-382d-48e5-a542-b6f6a3620a9b	80fbe013866def39ca01c070a5ea5bcae6a713f9c3792a16c5b3b5e648317314	\N	\N	\N	2026-06-27 10:33:49.701	\N	2026-05-28 10:33:49.703
fe268f14-1fb1-46e9-b404-8a714677f776	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	a9b201c6f49bbb3956fb620a886d4a157c1df96ecdbd19706d46a5e3b57fa292	\N	\N	\N	2026-06-27 10:34:17.711	\N	2026-05-28 10:34:17.713
04655484-eac3-4c67-81ea-13f7f983d7bf	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	fcb3d3f19d6a1548c148e1f1a16852dc42442e0fa8a4bbab001f773a7b8eac6c	\N	\N	\N	2026-06-27 10:35:17.808	\N	2026-05-28 10:35:17.81
97c049f9-ed41-48a6-a876-45e212076575	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	eba1f07fe8e518a48608b9a54c1c1b44e8aa894804c97c263c81d56e1beb5eec	\N	\N	\N	2026-06-27 10:36:21.618	\N	2026-05-28 10:36:21.62
53b132cf-f90b-4556-9394-bf70d630759a	90d6537e-9af8-48c1-8c44-acc1bac26dec	07e0b8ca4ba1388dc667a2ae1ec0c4fe2f067b152ff07050fbcbd4642a37c5df	\N	\N	\N	2026-06-27 10:36:21.827	\N	2026-05-28 10:36:21.828
b5894cf5-2387-43eb-a7c1-7b7ebb822736	aedd04e8-4140-437f-b66b-0f133c42b11f	be11bcea73841b00537a53b484dbcbbc73ce08cd08206af645d622b2112b3598	\N	\N	\N	2026-06-27 10:36:22.032	\N	2026-05-28 10:36:22.034
0f4f9b5e-7bdb-48dc-80ca-f91188fa029d	ab32baa0-382d-48e5-a542-b6f6a3620a9b	bdd2c37e95ba4710a5d80f728b75800d3d172b1463b4568dc69c1aa3f90b9d78	\N	\N	\N	2026-06-27 10:36:22.235	\N	2026-05-28 10:36:22.237
8a1a183d-2aab-4d8f-bbb3-5452ab240ffd	90d6537e-9af8-48c1-8c44-acc1bac26dec	7597655861c5dffb6e65cc2ab9d7eefd40e2febecb41a50d432e28be17d54b3e	\N	\N	\N	2026-06-27 11:44:02.632	\N	2026-05-28 11:44:02.634
19a1e4df-2c2a-462a-875b-cc15b625ece3	90d6537e-9af8-48c1-8c44-acc1bac26dec	13310f214f9b589cc4fac881dc1e4001d31552e4f4f59b0c0bdf136d784f9d13	\N	\N	\N	2026-06-27 12:00:40.686	\N	2026-05-28 12:00:40.687
d9d3a46a-3db9-4596-906b-47aec09bffff	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	7a092accad03bd78f9373a4d32164b9206a7ffdd63d68406147b793fe1e11b76	\N	\N	\N	2026-06-27 12:55:02.471	\N	2026-05-28 12:55:02.472
61ca6f36-a3dd-4b52-bcc3-666cc299def9	90d6537e-9af8-48c1-8c44-acc1bac26dec	e69a47cb7ae535722cfcf1a5c991a169e7cd7d17a63950a63e15c06af1413ef3	\N	\N	\N	2026-06-27 12:55:02.717	\N	2026-05-28 12:55:02.718
b5f2220f-1da7-4bdf-816d-9f5a47971ded	aedd04e8-4140-437f-b66b-0f133c42b11f	03800a116abe6789148ff87cbcfc0bb0e2470fed9af6a9e31a451a1545a242fc	\N	\N	\N	2026-06-27 12:55:02.952	\N	2026-05-28 12:55:02.953
b372a499-216b-469c-8948-c8217482a63a	ab32baa0-382d-48e5-a542-b6f6a3620a9b	20eaf055be71a353d1e15f9d2b3f883735e269171837ee3e8ded46d8d7020095	\N	\N	\N	2026-06-27 12:55:03.197	\N	2026-05-28 12:55:03.198
63a34913-07a3-40cc-b2f4-993c59d43a05	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	70bdbad611249c767b736160d75bcbd470310f7566d313329c48994bc0e2e8e3	\N	\N	\N	2026-06-27 12:55:43.415	\N	2026-05-28 12:55:43.416
301c0bdf-a6ce-451f-be88-ffb1a1d72659	90d6537e-9af8-48c1-8c44-acc1bac26dec	3b013491eae473f9e0eeed3520747e7062e801b3439fc7ec2319ee33ae3959c8	\N	\N	\N	2026-06-27 12:55:43.649	\N	2026-05-28 12:55:43.65
65347607-9ae8-4310-9f8d-dfea87a07e56	aedd04e8-4140-437f-b66b-0f133c42b11f	22652b225b815ac52909eed0c850e9ac1849f6302851b06445d61e61b36f7a4e	\N	\N	\N	2026-06-27 12:55:43.887	\N	2026-05-28 12:55:43.889
c91b9250-48d7-41ba-8ecd-3998ef15860d	ab32baa0-382d-48e5-a542-b6f6a3620a9b	2b65f2c5ff278b41dbead20a1622d3e11c66e37a27996ea406cca34ea9ee815e	\N	\N	\N	2026-06-27 12:55:44.136	\N	2026-05-28 12:55:44.138
2b7061af-9bd0-44e4-bc1e-6cd7dcdd009b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	70ca2c7000e379743591ca9262c6e7aa8cae23c9e0f29bf6a15ae0dd1989cdcd	\N	\N	\N	2026-06-27 12:56:10.736	\N	2026-05-28 12:56:10.737
d352fd2a-4243-4f7f-8863-1dc5d6dcd322	90d6537e-9af8-48c1-8c44-acc1bac26dec	d194719c17aa72f86097d7ba7eaff11e2edb8dc2eaa4ad819f759a51aa2910fb	\N	\N	\N	2026-06-27 13:08:58.052	\N	2026-05-28 13:08:58.054
6ff5b467-7af5-4ea6-9c31-a00911989583	90d6537e-9af8-48c1-8c44-acc1bac26dec	6d52ef19f0702d6d45c72b327dcf9593db320fa4237dba1e1c7aadc535ee35da	\N	\N	\N	2026-06-27 13:26:04.035	\N	2026-05-28 13:26:04.037
4b6c8b4f-8758-403d-8dcb-5ac3d030ad8b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	7ae15a8b3bae5b9ca628c7e750ca0aae1beeeaa9d1dd32de97bfc9631908ae8a	\N	\N	\N	2026-06-27 13:42:40.386	\N	2026-05-28 13:42:40.388
1e7122ae-9ab6-4035-bb35-4a878e31576a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	b3389cf3ec66bf286d5b2ab87a063e8d7a3124b79667aee697e0114acfbdf9cf	\N	\N	\N	2026-06-27 13:45:01.628	\N	2026-05-28 13:45:01.63
35a0e3ac-204e-414e-9437-17f409d03a74	90d6537e-9af8-48c1-8c44-acc1bac26dec	69e7432a875c36469a92ab30cffd10dfed83ee7892b10f8c1e4ae6059242b4bd	\N	\N	\N	2026-06-27 13:45:01.841	\N	2026-05-28 13:45:01.843
df342994-d490-4942-9de0-063cc9a3f2bd	aedd04e8-4140-437f-b66b-0f133c42b11f	92b37e096b0a4f0a8b0d88106e6e92c648f609106f18422d2c9f61e413e56786	\N	\N	\N	2026-06-27 13:45:02.12	\N	2026-05-28 13:45:02.121
5d9881ce-89c9-4cc8-956b-c775b178ee9b	ab32baa0-382d-48e5-a542-b6f6a3620a9b	8cbe386f42b9d3eae4cef7fc0a62460dd98fa4cd97ef7a589b7d8f99c450d160	\N	\N	\N	2026-06-27 13:45:02.391	\N	2026-05-28 13:45:02.392
4e12b170-ffbf-439e-82d1-fc6f1231c7bc	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	0dd1a485a5af58172b2af668f49da58670ef4cd2aed032a59d41dd97423a049a	\N	\N	\N	2026-06-27 13:45:42.493	\N	2026-05-28 13:45:42.495
de2cb439-17b1-41eb-ab53-7840ad3bef32	90d6537e-9af8-48c1-8c44-acc1bac26dec	d24d36938cf40db9d6b2008e5d26b41eca2fc2003fde8cd3e7d554cf0a9853ff	\N	\N	\N	2026-06-27 13:45:42.765	\N	2026-05-28 13:45:42.767
201497ee-835e-47e4-81e9-5692bf135128	aedd04e8-4140-437f-b66b-0f133c42b11f	569c411c859f7fd1dbd1d52e35292fe985127a67208fb06f514cbe1ea3a7471e	\N	\N	\N	2026-06-27 13:45:43.001	\N	2026-05-28 13:45:43.002
d8d010a3-dfeb-4b67-a5ea-7de98e483ef7	ab32baa0-382d-48e5-a542-b6f6a3620a9b	5a6a5fd60ff2b1df7e2a3b49b92f1c2b79a4e8235c5437f9182b24046ed988b1	\N	\N	\N	2026-06-27 13:45:43.253	\N	2026-05-28 13:45:43.254
15e1af36-6d02-4d41-8c24-4718bcb2d82a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	83baaf2e76a143d23b5758cb45fca5c26937f6b62057df3d5b5784a075355d31	\N	\N	\N	2026-06-27 13:47:18.706	\N	2026-05-28 13:47:18.708
6b2c463a-f3fb-4211-82e7-ceaaa76a7e2b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	52af09d129c744d73ab73e0222085cfda55ddeef27e0c5e19c8cc0b0cbcdacea	\N	\N	\N	2026-06-27 13:51:05.502	\N	2026-05-28 13:51:05.505
c1424947-effa-4636-a0cc-8c5a53a1895b	90d6537e-9af8-48c1-8c44-acc1bac26dec	1a836e4f4805af43562ec4b17f25819d40af6983c6b949eb89c4b68f94e091c6	\N	\N	\N	2026-06-27 13:51:05.805	\N	2026-05-28 13:51:05.808
de24e8ce-200b-438e-ab43-669b1930d79e	aedd04e8-4140-437f-b66b-0f133c42b11f	74a219c7d5a3d85f320ff38201f554544ae910f7fbacc42c2cb203de6b059cff	\N	\N	\N	2026-06-27 13:51:06.054	\N	2026-05-28 13:51:06.057
a55bf87b-4073-4303-a301-455b772b7133	ab32baa0-382d-48e5-a542-b6f6a3620a9b	3bf0d376d15cbf710f226619c38ee30fa34e83706ffbd3a4d0725e23b4384f01	\N	\N	\N	2026-06-27 13:51:06.241	\N	2026-05-28 13:51:06.245
cf90a1a4-e307-4671-a834-c139e4f1766b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	ef29357f969e773a61812b3e22d510020a91a114b0ceafe27a58234cf496cdf1	\N	\N	\N	2026-06-27 13:51:11.3	\N	2026-05-28 13:51:11.304
81720c16-a8e0-4521-9a0a-4a0869459890	90d6537e-9af8-48c1-8c44-acc1bac26dec	4512f86fad500ea9277dc5f4e29cd257043db8586b58e58a97e559918724fe9e	\N	\N	\N	2026-06-27 13:51:11.563	\N	2026-05-28 13:51:11.566
402ffe3d-23d2-48e8-bf13-27d60e27ffd6	aedd04e8-4140-437f-b66b-0f133c42b11f	c320b7a020645f614a4e63515390b20c0562ab5e7f98bacae8f63aa7c1391643	\N	\N	\N	2026-06-27 13:51:11.79	\N	2026-05-28 13:51:11.794
9eddc045-a077-4f0e-9b66-6988e2a959ca	ab32baa0-382d-48e5-a542-b6f6a3620a9b	e02602541e55747385ed4ff1dccb763b9b88011cc78b57a346b044b4cea43be9	\N	\N	\N	2026-06-27 13:51:12.049	\N	2026-05-28 13:51:12.052
e64c2035-bd54-4cd3-9ae0-bc180a87c372	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	9d5922235632d6ac33fd47e3d422b0062afe10d80a93ea82c4bb9b8c547d2999	\N	\N	\N	2026-06-27 14:56:48.099	\N	2026-05-28 14:56:48.101
6556ab84-587a-4888-abfc-d5fceef535c5	90d6537e-9af8-48c1-8c44-acc1bac26dec	a599d89603a5acd393eee65b693a3e792f23f8d1f27b9eb4c906a5188d203ee6	\N	\N	\N	2026-06-27 14:56:48.386	\N	2026-05-28 14:56:48.387
326efe4d-138f-436e-a8de-daa61860efb8	aedd04e8-4140-437f-b66b-0f133c42b11f	70f7dfe07de44bb1544bc6a46bbc0672fa0f8db9b68582f7aa61492f94875294	\N	\N	\N	2026-06-27 14:56:48.665	\N	2026-05-28 14:56:48.666
21775814-4b66-4d00-8d8d-9154ae0465c0	ab32baa0-382d-48e5-a542-b6f6a3620a9b	fae4209be0fec291fa4ddbe89af214b143d75e8529f06d52d22f9fb55a3db3a3	\N	\N	\N	2026-06-27 14:56:48.936	\N	2026-05-28 14:56:48.937
c2eee603-594a-4d74-9725-f033c3635f10	90d6537e-9af8-48c1-8c44-acc1bac26dec	3d26fe405655d3ff7c16738b738ab1621fe814c0ae2c2625023320cdf64b5356	\N	\N	\N	2026-06-27 18:02:57.998	\N	2026-05-28 18:02:57.999
16b293f8-604d-45e2-a727-7dfcc1056dfc	90d6537e-9af8-48c1-8c44-acc1bac26dec	198be77a14cb7f1e1c8c5b7297c7f45542e13eb9eafcc04e815735911beab7d5	\N	\N	\N	2026-06-27 18:03:21.717	\N	2026-05-28 18:03:21.719
3be65d29-1b36-4290-bae0-fbfb19b3bf1b	90d6537e-9af8-48c1-8c44-acc1bac26dec	f42c825a1943185a6c15b9814a5aaa2fc67857fcb19c8caf2fcfc573ed187fb7	\N	\N	\N	2026-06-27 18:31:20.312	\N	2026-05-28 18:31:20.313
a84a1a04-41ad-460b-85e3-ec7fbb48fa6a	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	5d7f8db328f3faaba5397c7f09b28a48b0259b891fb912e2ea49c0e921c1f83c	\N	\N	\N	2026-06-27 18:31:20.514	\N	2026-05-28 18:31:20.515
d48b4f97-acf9-41c3-a657-97f5d93cd9c7	aedd04e8-4140-437f-b66b-0f133c42b11f	7aefdab4a7826f0938cba6e3dc2680d2cace3fef5d28de45cf9ee5fbd372c542	\N	\N	\N	2026-06-27 18:31:27.108	\N	2026-05-28 18:31:27.112
c0684b55-18d1-469b-b70c-5b0f8aa5370a	ab32baa0-382d-48e5-a542-b6f6a3620a9b	a2aaadc01a424c414c41d3cea240e44350b7011c482b201fc9060538ad43e375	\N	\N	\N	2026-06-27 18:31:27.497	\N	2026-05-28 18:31:27.5
686be89f-6c03-424f-a04d-a8846e3eaae4	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	a5964956fda3b9a0db346d20bde272128583d550a434c06fa18d1730e3d886bc	\N	\N	\N	2026-06-28 06:54:13.356	\N	2026-05-29 06:54:13.363
3eec8402-a417-46c6-a588-bdf9cf01cddc	90d6537e-9af8-48c1-8c44-acc1bac26dec	c8a3370b2f5cd86042c84566273ac9fec7d2bd416db4bda1a8d0b6f0c44ab893	\N	\N	\N	2026-06-28 07:25:43.841	\N	2026-05-29 07:25:43.843
fad6dbd6-95c1-489e-9f1b-d9741dc0cb9b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	2a7a6b5e98598fe1cbba28dae3c4de77dd41d9e87106da738b32a611b4e586e8	\N	\N	\N	2026-06-28 08:01:16.295	\N	2026-05-29 08:01:16.299
7a970f18-bdb2-4ac1-8879-1104c5a42e96	90d6537e-9af8-48c1-8c44-acc1bac26dec	628c400d19a35737e42d4467aeb2f570cf8a04166de59d45e2f4ba0e6325a8dc	\N	\N	\N	2026-06-28 08:01:16.59	\N	2026-05-29 08:01:16.591
ff29af60-5721-47f3-b074-7ffdf8afacd2	aedd04e8-4140-437f-b66b-0f133c42b11f	60dafa02570adf1d0dd1d8265554bcdb71346100b25befed3e535217e36e39ed	\N	\N	\N	2026-06-28 08:01:16.901	\N	2026-05-29 08:01:16.902
0f96a06d-67d7-4008-b44c-42eacbab50db	ab32baa0-382d-48e5-a542-b6f6a3620a9b	da56f491ffd673f4c066643fb909e5bda35d46c31e08a0d858747e1661cbe767	\N	\N	\N	2026-06-28 08:01:17.146	\N	2026-05-29 08:01:17.147
820da3d6-08f8-43a7-9bd6-19f3cdc7b4c2	61f1af85-9347-49d4-86a3-cb858d5a0b69	8b15423bc101f3887791d1166e86458fd443af7573f076aa8ef0656bd40d1fe3	\N	\N	\N	2026-06-28 08:01:19.449	\N	2026-05-29 08:01:19.45
f0f2666f-839d-417d-b5e7-de2419e7ec1b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	7a5801bc84875df50237399db1b5f5d7cfd0d82265ccfddf6a9730aac9b28d56	\N	\N	\N	2026-06-28 08:02:41.503	\N	2026-05-29 08:02:41.504
f356c4f3-9ef4-4dd1-bef2-567b3f656cca	90d6537e-9af8-48c1-8c44-acc1bac26dec	05da7e3f1b1450e85c6944903e2b633d4095419e3728a94bc8b479b74590a172	\N	\N	\N	2026-07-02 08:48:07.982	\N	2026-06-02 08:48:07.986
ada48403-3407-4994-a416-67f06919126e	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	a4a83a2123cd88e496f7fa9c485ad4edbee7cd2d7041808e3f43c2b88c129c44	\N	\N	\N	2026-07-02 08:57:28.84	\N	2026-06-02 08:57:28.841
e88e0e7e-3081-43ec-aeec-31945a6ee994	90d6537e-9af8-48c1-8c44-acc1bac26dec	a447932862132398d3dffb159218f7012999250f06db243422970f6c146a89d0	\N	\N	\N	2026-07-02 08:57:29.392	\N	2026-06-02 08:57:29.393
7af5924c-3fcb-491c-a77d-838e986adee9	aedd04e8-4140-437f-b66b-0f133c42b11f	fa90261c5914aeeccd53edbfccd936d382afe84e30f8396084b21b76d5ea0382	\N	\N	\N	2026-07-02 08:57:29.808	\N	2026-06-02 08:57:29.81
c9ae540f-a772-4a53-a9d5-58ffce74454e	ab32baa0-382d-48e5-a542-b6f6a3620a9b	4f9cfe1c05b0b88600ec7cf811357c27b0c9e6c4496e183e4ceaef7bec6b4b75	\N	\N	\N	2026-07-02 08:57:30.808	\N	2026-06-02 08:57:30.809
87319781-2b66-4a48-8987-67175c23b57d	d70495ff-161a-4f2b-a817-540ca2658367	d46f3b2dee5eaa841d567e351f6215285b598b0dd2bc72c43c34c8dc8bddc2fa	\N	\N	\N	2026-07-02 08:57:34.241	\N	2026-06-02 08:57:34.242
d407cd05-9192-43b2-aaeb-572ee9d27d12	90d6537e-9af8-48c1-8c44-acc1bac26dec	5c2125e5d521a27e611f0a8d93e41ba2ba03bc871e04db77b2fb70083275849d	\N	\N	\N	2026-07-02 09:22:06.927	\N	2026-06-02 09:22:06.929
5b97a9c8-8366-4320-8106-8f406552c87e	90d6537e-9af8-48c1-8c44-acc1bac26dec	cbce8856fba76d7a6efc2af511a4652123771854a9fd00ce8c211ea053ec6122	\N	\N	\N	2026-07-02 09:24:38.264	\N	2026-06-02 09:24:38.267
4e1b1634-df7d-4d49-8b42-e0903c490c29	90d6537e-9af8-48c1-8c44-acc1bac26dec	28d549bb81dcab1acaa3bb4f383bca7881830152a918cf9deabd4e4fcd0a05c1	\N	\N	\N	2026-07-02 09:35:24.959	\N	2026-06-02 09:35:24.964
31c446c6-b3fc-46bf-af70-c90d4a3e9d07	aedd04e8-4140-437f-b66b-0f133c42b11f	6df70d55541bfabd7e28d8ddb1b9ab19ef81da1403df499f3dfe4dcb32059472	\N	\N	\N	2026-07-02 09:35:39.044	\N	2026-06-02 09:35:39.045
a62818c7-a580-482d-9d36-ebcec0776999	aedd04e8-4140-437f-b66b-0f133c42b11f	c832c4e7b0d8bd4af39dd6b0970402b88b2e9b40c016ecf68dde0ba700f665ef	\N	\N	\N	2026-07-02 09:51:38.839	\N	2026-06-02 09:51:38.84
44c0878c-3818-4667-8531-51609122add8	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	8ccfaf8fa0c4ab58d4aaebca3e24c01d28ee44bb9cf36fef93e7805400d300df	\N	\N	\N	2026-07-02 10:34:24.171	\N	2026-06-02 10:34:24.173
57a9efdf-1e7d-42b5-b787-589b0108740a	90d6537e-9af8-48c1-8c44-acc1bac26dec	6fd5877c1dd254a4cca0a61673c0c64cdc25dc13998a17f0d38670f0599a98c8	\N	\N	\N	2026-07-02 10:34:24.427	\N	2026-06-02 10:34:24.429
aa288a27-dd53-403d-a948-b0837b362bc8	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	30806ab29595f0f55d37fb35dcc244b18cee79115417a30df553a0ec8c093510	\N	\N	\N	2026-07-02 10:35:35.495	\N	2026-06-02 10:35:35.497
24767f28-e855-4810-b15e-0e5bc13b8715	aedd04e8-4140-437f-b66b-0f133c42b11f	32dd98615488754114a61cc6715507ed37428b73fa332e2ff1edcc92bb200ee5	\N	\N	\N	2026-07-02 10:36:00.277	\N	2026-06-02 10:36:00.279
ea851edb-c624-46bd-bbc6-8b9c5deddddc	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	1f9a85c7f141e5c52602d4d3e7215f53fb33a535b577fa83976baf3ac11b8b4b	\N	\N	\N	2026-07-02 10:54:08.478	\N	2026-06-02 10:54:08.484
a1e8ddf7-d473-4143-a584-ff3a333721bb	90d6537e-9af8-48c1-8c44-acc1bac26dec	e4480afe1d515832787cfb449ad81206f2f5bd0da1fdc3664fe2a1e5a6e8f795	\N	\N	\N	2026-07-02 10:54:08.73	\N	2026-06-02 10:54:08.731
22e78b02-c515-411a-a81b-6bbdf06dc638	ab32baa0-382d-48e5-a542-b6f6a3620a9b	f73a491864c48af7ae9917dc75963e6b2a9282e2e6a7c027822191b8442c53ae	\N	\N	\N	2026-07-02 10:54:08.942	\N	2026-06-02 10:54:08.944
b7a5d88e-893f-470b-9c13-8ad57772048d	90d6537e-9af8-48c1-8c44-acc1bac26dec	2e374473ee1ce9af4e36c7722e502a9cadc8aa73755d719340bc0d3d27c44ea2	\N	\N	\N	2026-07-02 11:04:06.472	\N	2026-06-02 11:04:06.473
87e8d16d-8f9e-4005-b24c-083115ce7c35	ab32baa0-382d-48e5-a542-b6f6a3620a9b	c96f5af7104125d0c3d04783aaee2a73f68508842caccbe929d465f1dd1cfa72	\N	\N	\N	2026-07-02 11:04:24.723	\N	2026-06-02 11:04:24.724
832358e5-a5e0-4c18-a26e-1aefede41589	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	80ce79b835240ac0f8fd786e8fd5d7dc37f1229d87714e74329d5965b1640e57	\N	\N	\N	2026-07-02 11:04:42.069	\N	2026-06-02 11:04:42.07
3f8e59d1-6f62-4eef-912f-cf3c5316be69	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	609c293de01fba3b14af6685b70c60a6e7d1ca69a78676b7bd13ce43d1332381	\N	\N	\N	2026-07-02 11:09:20.21	\N	2026-06-02 11:09:20.211
ec7bb789-57b0-4e74-8c16-cd524a3abc48	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	a38db12d2ce267c655b0b1705960c5615f32006fd79164473e936b9ea88b6fbb	\N	\N	\N	2026-07-04 07:19:27.156	\N	2026-06-04 07:19:27.158
413bd46c-7a4e-4dbd-a2ab-9009404f7747	aedd04e8-4140-437f-b66b-0f133c42b11f	9a2b08de6230325849c2972bb92405698b2e8f9841cdff8a92322dccc2d28230	\N	\N	\N	2026-07-04 08:08:53.211	\N	2026-06-04 08:08:53.213
06562ef7-bb18-4c27-b778-74bb777e5ef4	90d6537e-9af8-48c1-8c44-acc1bac26dec	8cb17ffa511f16d9f5c78ae7404ecdb88c536a58b0dc7d9227809a3b5f246972	\N	\N	\N	2026-07-04 08:09:57.422	\N	2026-06-04 08:09:57.423
16689a2e-ae21-432f-acef-b0604e527c10	aedd04e8-4140-437f-b66b-0f133c42b11f	a0ed1e9ebbca8a4d872ffc903331b953e6c2f36c6ae34b8b5fdbc533ff2336d0	\N	\N	\N	2026-07-04 13:47:14.506	\N	2026-06-04 13:47:14.508
e49a51d7-deca-46c8-a03f-448be9e3fb0a	aedd04e8-4140-437f-b66b-0f133c42b11f	46ea8531645cfe7e43065c994f0ca7526d1fd2e1a8eb391c978f407ba87af906	\N	\N	\N	2026-07-04 14:11:19.881	\N	2026-06-04 14:11:19.883
338818e9-804b-4bf1-a0d9-d0e15c16b44b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	09bbd745827dab4b48707acfb5ed7179faa8eb2a85f52cc1056758081e3eadc1	\N	\N	\N	2026-07-04 14:11:20.175	\N	2026-06-04 14:11:20.176
acef4223-d7c1-450c-b63d-67609074af0c	aedd04e8-4140-437f-b66b-0f133c42b11f	97fb1eabb42ed10a8ff7e82b986874c4c7c8cacc9ed9e60c0ca8d56de9749a62	\N	\N	\N	2026-07-04 14:24:45.557	\N	2026-06-04 14:24:45.558
7b207ef8-8196-441b-bcc1-43f3445b36b7	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	aa34450f9dd41009b113beb1e0fbbaf510f29a267f93225d2fcd7dc76f36cb44	\N	\N	\N	2026-07-04 14:24:45.787	\N	2026-06-04 14:24:45.788
52aa58b3-66a2-44bf-a71a-c9fa830fed11	90d6537e-9af8-48c1-8c44-acc1bac26dec	0ae089e312ec3d4b0652add0d62559f761b7494ae36504b3bd5d0084823aa6a8	\N	\N	\N	2026-07-04 14:24:46.018	\N	2026-06-04 14:24:46.019
dcc531ed-e782-4ded-82c7-31be056656c5	aedd04e8-4140-437f-b66b-0f133c42b11f	60b35e048f46e0140c115d68a88fd76c26d6b88c61c0594a4d167876012d912a	\N	\N	\N	2026-07-04 14:25:14.216	\N	2026-06-04 14:25:14.217
c1f4be77-0820-4242-bb66-8aecd1bc189b	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	42e091b390605b9a2467ee52f801d09a88e67e6977770b54258e52a08ea5bdd2	\N	\N	\N	2026-07-04 14:25:14.916	\N	2026-06-04 14:25:14.917
6091531c-6500-47ff-bca8-60e56c20b5ec	90d6537e-9af8-48c1-8c44-acc1bac26dec	6cba7712cc19d9a13ff03d89964cbe860cef2917115e489498a3df86dfde7433	\N	\N	\N	2026-07-04 14:25:15.186	\N	2026-06-04 14:25:15.188
9119e1b0-bc3f-48a1-b945-37729ca9361d	aedd04e8-4140-437f-b66b-0f133c42b11f	c67761d6bdbe50cc0eb831409da1f49b0dda58c97ef82b9ad5a823cd77a91f45	\N	\N	\N	2026-07-04 14:25:15.423	\N	2026-06-04 14:25:15.425
033ce61a-5d0c-4fed-9602-14e5ce96c8b8	ab32baa0-382d-48e5-a542-b6f6a3620a9b	f46cb9c643a409be38294f6181e775314c07d5dfda5b11a29994a8f56ebeefe4	\N	\N	\N	2026-07-04 14:25:15.641	\N	2026-06-04 14:25:15.642
bb561145-de8d-4170-93c7-4fddfaa87e07	0502db59-3b85-40bc-9325-3556c61967c1	5e0a1da1b2c152b153f30db4431141e56ee2ccc25aef4c86d27d39375bafccec	\N	\N	\N	2026-07-04 14:25:17.85	\N	2026-06-04 14:25:17.852
b58b5456-495f-4546-8443-46e19c4f044e	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	862de431d9590acd01c7985632d8199d42e13e8a8f051de95ddbaa5848f13f4d	\N	\N	\N	2026-07-04 14:25:38.88	\N	2026-06-04 14:25:38.881
92eb9fc8-a485-40b0-b220-91c6932ca93e	90d6537e-9af8-48c1-8c44-acc1bac26dec	394694de528b987bd8f7e3e3e01b78b87de350256c1ff62f8573e122b4007153	\N	\N	\N	2026-07-04 14:25:39.117	\N	2026-06-04 14:25:39.119
5165f814-5066-48f9-afc6-9a04c3dd6193	aedd04e8-4140-437f-b66b-0f133c42b11f	b8d47fc1752f51c4642bdd4ef804b2755bb2766ab188b7dc3c5a96d453acebe1	\N	\N	\N	2026-07-04 14:34:24.355	\N	2026-06-04 14:34:24.357
19bf8643-2aa8-45b8-9a2c-ff77228523f7	aedd04e8-4140-437f-b66b-0f133c42b11f	ab01a7fd28a4b89d6892ab5c8545529dfc947ebd18ab80c5a09d955df193dfb9	\N	\N	\N	2026-07-04 14:40:22.315	\N	2026-06-04 14:40:22.316
857cb0ec-c9f5-435c-82a6-f949f2ddf192	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	e0a80efb24bce1be688ed83aa2680d06fc801ec8c7b010e921b724581cbe73e9	\N	\N	\N	2026-07-04 14:41:55.203	\N	2026-06-04 14:41:55.204
f9e2b2ac-59aa-4955-9471-93f8fdbef358	aedd04e8-4140-437f-b66b-0f133c42b11f	d1f6ae05501f0d6b30d4dc411cf20a747772ae2fdd895ffcd92a39f7d67c977d	\N	\N	\N	2026-07-04 14:42:24.208	\N	2026-06-04 14:42:24.209
6b01fc87-e276-44a9-8653-a0c745fadbb6	aedd04e8-4140-437f-b66b-0f133c42b11f	f7ed37621b5b421bdf2f4681b6942b5d8bdc0db54dcba2bf214bd869a0710081	\N	\N	\N	2026-07-04 14:51:19.37	\N	2026-06-04 14:51:19.372
\.


ALTER TABLE public."RefreshToken" ENABLE TRIGGER ALL;

--
-- Data for Name: Refund; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Refund" DISABLE TRIGGER ALL;

COPY public."Refund" (id, "orderId", "paymentId", amount, reason, status, "requestedById", "approvedById", "providerRef", "createdAt", "updatedAt") FROM stdin;
\.


ALTER TABLE public."Refund" ENABLE TRIGGER ALL;

--
-- Data for Name: Review; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Review" DISABLE TRIGGER ALL;

COPY public."Review" (id, "productId", "userId", "orderId", rating, body, images, status, "moderationNote", "createdAt", "updatedAt") FROM stdin;
\.


ALTER TABLE public."Review" ENABLE TRIGGER ALL;

--
-- Data for Name: SiteContent; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."SiteContent" DISABLE TRIGGER ALL;

COPY public."SiteContent" (key, data, "updatedAt") FROM stdin;
\.


ALTER TABLE public."SiteContent" ENABLE TRIGGER ALL;

--
-- Data for Name: StoreBlackoutDate; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."StoreBlackoutDate" DISABLE TRIGGER ALL;

COPY public."StoreBlackoutDate" (id, "storeId", date, reason, "createdAt") FROM stdin;
\.


ALTER TABLE public."StoreBlackoutDate" ENABLE TRIGGER ALL;

--
-- Data for Name: Thread; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."Thread" DISABLE TRIGGER ALL;

COPY public."Thread" (id, "storeId", "authorId", title, body, "imageUrl", "publishedAt", "createdAt", "updatedAt", images, hashtags, "productId", "ctaLabel", "ctaUrl", "scheduledPublishAt", "viewCount") FROM stdin;
\.


ALTER TABLE public."Thread" ENABLE TRIGGER ALL;

--
-- Data for Name: WishlistItem; Type: TABLE DATA; Schema: public; Owner: -
--

ALTER TABLE public."WishlistItem" DISABLE TRIGGER ALL;

COPY public."WishlistItem" (id, "userId", "productId", "createdAt") FROM stdin;
a9592838-ca86-4011-987d-990f7a02fd24	29a15df2-8b8c-4e4b-9c46-4e7e2a87d518	5bc02b3e-474c-4fed-af08-f9dc8caf42ef	2026-05-28 13:47:27.352
\.


ALTER TABLE public."WishlistItem" ENABLE TRIGGER ALL;

--
-- PostgreSQL database dump complete
--

\unrestrict 6D573YpawBCkgf7Z3kNRqzArPzxlWPhKTp0oeQDdKGHaVE13vhq9T0YShvCl5bT


-- Xoa du lieu giao dich test (ghi ro public. vi dump da reset search_path)
SET search_path TO public;
TRUNCATE public."Order", public."OrderItem", public."OrderStatusEvent", public."Payment", public."Notification", public."LoyaltyEvent", public."RefreshToken", public."Address", public."GiftCard" CASCADE;
