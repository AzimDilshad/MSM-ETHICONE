# Cloudinary document uploads

Set `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET` as Supabase Edge Function secrets. Deploy with `supabase functions deploy create-document-upload`. The function checks the caller's Supabase session and organisation membership before signing a 10 MB max upload. Keep the Cloudinary API secret server-side.
