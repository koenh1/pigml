wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test --method=DELETE http://localhost:8040/orion/workspace/E1
wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test --method=DELETE http://localhost:8040/orion/workspace/E2

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test --header=Slug:MyWorkSpace --post-data=x http://localhost:8040/orion/workspace 
wget -S -O out.txt -d -v --http-user=admin --http-password=admin --header=Slug:MyWorkSpace2 --post-data=x http://localhost:8040/orion/workspace 

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test --header=Slug:NewProject --post-data=x http://localhost:8040/orion/workspace/E1 
wget -S -O out.txt -d -v --http-user=admin --http-password=admin --header=Slug:NewProject2 --post-data=x http://localhost:8040/orion/workspace/E2 

wget -S -O out.txt -d -v --http-user=admin --http-password=admin --post-data={ContentLocation:\"/orion/file/A1\"\,Name:\"X\"} http://localhost:8040/orion/workspace/E2 --header=Content-Type:application/json

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test --header=X-Create-Options:move --post-data={Location:\"/orion/file/X\"\,Name:\"X\"} http://localhost:8040/orion/workspace/E1 --header=Content-Type:application/json

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1' --header='Content-Type: application/json' --header='X-Create-Options: no-overwrite' --header='Slug: File' --post-data='{"Name":"File","LocalTimeStamp":"0","Directory":false}' 
wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1' --header='Content-Type: application/json' --header='X-Create-Options: no-overwrite' --header='Slug: Folder' --post-data='{"Name":"Folder","LocalTimeStamp":"0","Directory":true}' 

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/Folder/' --header='Content-Type: application/json' --header='X-Create-Options: no-overwrite' --header='Slug: a.txt' --post-data='{"Name":"a.txt","LocalTimeStamp":"0","Directory":false}' 
wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/Folder/a.txt' --header='Content-Type: text/plain' --method=PUT --body-data=testing

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/Folder/' --header='Content-Type: application/json' --header='X-Create-Options: no-overwrite,copy' --header='Slug: aa.txt' --post-data='{"Name":"aa.txt","Location":"/file/E1/A1/Folder/a.txt"}' 
wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/Folder/' --header='Content-Type: application/json' --header='X-Create-Options: no-overwrite,move' --header='Slug: bb.txt' --post-data='{"Name":"bb.txt","Location":"/file/E1/A1/Folder/a.txt"}' 

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/' --header='Content-Type: application/json' --header='X-Create-Options: no-overwrite,move' --header='Slug: Folder2' --post-data='{"Name":"Folder2","Location":"/file/E1/A1/Folder/"}' 

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/Folder/bb.txt' --header='Content-Type: application/json' --header='If-Match:55475167d945e279' --method=DELETE


wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/File?parts=meta' 
wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/File?parts=body' 

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/File' --header='Content-Type: text/plain' --method=PUT --body-data=ababab

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/File' --header='Content-Type: application/json' --header=If-Match:fe2eab35eabfb994 --header=X-HTTP-Method-Override:PATCH --post-data='{"diff":[{"start":0,"end":2,"text":"abc"},{"start":3,"end":5,"text":"abc"},{"start":6,"end":8,"text":"abc"}]}'


wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/File' --header='Content-Type: application/json' --header=If-Match:108893127d8eb7ca --header=X-HTTP-Method-Override:PATCH --post-data='{"diff":[{"start":5,"end":10,"text":""}]}'

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/File' --header='Content-Type: application/json'  --header=X-HTTP-Method-Override:PATCH --post-data='{"diff":[{"start":0,"end":1,"text":""}]}'

wget -S -O out.txt -d -v --http-user=pigml-user --http-password=test 'http://localhost:8040/orion/file/E1/A1/' --header='Content-Type: application/json'  --method=DELETE

