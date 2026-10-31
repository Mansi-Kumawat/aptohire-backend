insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('videos','videos',false,52428800,array['video/mp4','video/webm','video/quicktime']),
 ('documents','documents',false,20971520,array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','text/markdown','application/zip']),
 ('rosters','rosters',false,20971520,array['text/csv']),
 ('avatars','avatars',false,1048576,array['image/jpeg']),
 ('resumes','resumes',false,20971520,array['application/pdf']) on conflict(id) do nothing;
-- Owners are derived from the path, never object metadata. No organization access is granted.
create policy student_storage_select on storage.objects for select to authenticated using(
 (bucket_id in ('videos','documents') and (storage.foldername(name))[1]=private.my_student_id()::text)
 or (bucket_id='avatars' and name=private.my_student_id()::text||'.jpg')
 or (bucket_id='resumes' and (storage.foldername(name))[1]=private.my_student_id()::text));
create policy student_storage_insert on storage.objects for insert to authenticated with check(
 (bucket_id in ('videos','documents') and (storage.foldername(name))[1]=private.my_student_id()::text)
 or (bucket_id='avatars' and name=private.my_student_id()::text||'.jpg')
 or (bucket_id='resumes' and (storage.foldername(name))[1]=private.my_student_id()::text));
create policy student_storage_update on storage.objects for update to authenticated using(
 (bucket_id in ('videos','documents') and (storage.foldername(name))[1]=private.my_student_id()::text)
 or (bucket_id='avatars' and name=private.my_student_id()::text||'.jpg')
 or (bucket_id='resumes' and (storage.foldername(name))[1]=private.my_student_id()::text)) with check(
 (bucket_id in ('videos','documents') and (storage.foldername(name))[1]=private.my_student_id()::text)
 or (bucket_id='avatars' and name=private.my_student_id()::text||'.jpg')
 or (bucket_id='resumes' and (storage.foldername(name))[1]=private.my_student_id()::text));
create policy student_storage_delete on storage.objects for delete to authenticated using(
 (bucket_id in ('videos','documents') and (storage.foldername(name))[1]=private.my_student_id()::text)
 or (bucket_id='avatars' and name=private.my_student_id()::text||'.jpg')
 or (bucket_id='resumes' and (storage.foldername(name))[1]=private.my_student_id()::text));
create policy university_roster_objects on storage.objects for all to authenticated using(bucket_id='rosters' and (storage.foldername(name))[1]=any(select unnest(private.my_university_ids())::text)) with check(bucket_id='rosters' and (storage.foldername(name))[1]=any(select unnest(private.my_university_ids())::text));
