.PHONY: serve stop ports swagger build clean

serve:
	swift run server serve --port 8080

stop:
	@pkill -f "server serve" 2>/dev/null && echo "서버 종료됨" || echo "실행 중인 서버 없음"

ports:
	@lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR==1 || /LISTEN/' || echo "리스닝 포트 없음"

swagger:
	open http://localhost:8080/swagger

build:
	swift build

clean:
	swift package clean
