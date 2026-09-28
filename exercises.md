# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay các dòng mẫu bằng câu trả lời của bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Hoàng Ngọc Đăng Khoa  Mã học viên: 2A202602790

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.
>
Nếu tôi quên khai báo biến `AGENT_API_KEY` trong dashboard và để giá trị mặc định là `"changeme"`, app vẫn khởi động bình thường. Kẻ tấn công hoặc bot quét tự động có thể dùng key `"changeme"` để gọi API miễn phí và tiêu sạch ngân sách LLM mà tôi không hề hay biết cho đến khi xem hóa đơn. Khi không có giá trị mặc định, app crash ngay lập tức với lỗi `ValidationError` lúc startup. Lỗi này hiện ra ngay trên màn hình deploy, giúp tôi phát hiện và bổ sung cấu hình.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.
>
Dòng log JSON thu được:
`{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T09:23:55.789123+00:00", "user_id": "sv-test", "tokens_in": 12, "tokens_out": 38, "cost_usd": 0.00012}`

Hai việc làm được với log JSON:
1. Lọc, tìm kiếm và tạo cảnh báo tự động trên hệ thống log: Dễ dàng parse cấu trúc JSON theo trường, ví dụ lọc ra tất cả request của một `user_id` cụ thể hoặc bắt sự kiện có `cost_usd` bất thường.
2. Thống kê và tính toán chi phí chính xác: Trích xuất các trường định lượng (`cost_usd`, `tokens_in`, `tokens_out`) để cộng dồn, vẽ dashboard theo dõi lượng token tiêu thụ theo thời gian thực mà không cần viết regex để bóc tách chuỗi thô.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1020 MB |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?
>
Phần dung lượng chênh lệch (~750 MB) bao gồm:
1. Base image gốc (`python:3.11` full) chứa đầy đủ các trình biên dịch (gcc, g++, make), header C/C++ và các gói hệ thống nặng nề. Base `python:3.11-slim` đã lược bỏ toàn bộ các gói không cần thiết này.
2. Quá trình multi-stage chỉ copy thư mục cài đặt package cuối cùng (`/install` sang `/usr/local`), không kéo theo pip cache, build artifacts hay dependency trung gian vào image runtime cuối.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?
>
- Với Dockerfile hiện tại: Docker cache lại toàn bộ các layer trước đó gồm base image, `COPY requirements.txt .`, và `RUN pip install ...` (sử dụng `CACHED`). Chỉ có layer `COPY app ./app` và các chỉ thị bên dưới được thực thi lại, thời gian build chỉ mất 1-2 giây.
- Nếu đặt `COPY . .` trước `RUN pip install`: Khi sửa 1 ký tự trong `app/main.py`, cache của layer `COPY . .` bị mất hiệu lực. Khi đó, layer `RUN pip install` bắt buộc phải chạy lại từ đầu, khiến Docker phải tải và cài đặt lại toàn bộ thư viện, làm thời gian build kéo dài từ vài giây lên vài phút mỗi lần thay đổi code.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.
>
Chuỗi sự kiện:
1. App Python xuất hiện lỗ hổng thực thi mã từ xa.
2. Kẻ tấn công khai thác lỗ hổng để chạy shell command bên trong container.
3. Vì container chạy mặc định bằng root (UID 0), kẻ tấn công chiếm quyền root trong container.
4. Kẻ tấn công lợi dụng các kỹ thuật container escape hoặc volume mount nhạy cảm để thoát ra ngoài máy host. Vì UID 0 trong container map thẳng tới root trên máy host Linux (khi không dùng user namespace), kẻ tấn công kiểm soát toàn bộ máy chủ vật lý.
Lệnh `USER appuser` cắt đứt chuỗi ở bước 3: Tiến trình app chỉ chạy với user thường không có quyền quản trị (UID 10001). Khi đó, kẻ tấn công dù có chèn được mã cũng chỉ có quyền bị giới hạn của `appuser`, không thể sửa file hệ thống và không thể khai thác quyền sang host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.
>
Người dùng có thể gửi tối đa 20 request trong 2 giây liên tiếp.
Cách đạt được:
- Người dùng gửi 10 request ở giây `10:00:59` (giây cuối cùng của phút thứ nhất, hợp lệ vì đúng hạn mức 10/phút).
- Khi bước sang giây `10:01:00`, bộ đếm theo phút đồng hồ được reset về 0.
- Người dùng gửi tiếp 10 request ở giây `10:01:01` (thuộc phút thứ hai, vẫn hợp lệ).
Như vậy trong 2 giây liên tiếp (`10:00:59` đến `10:01:01`), người dùng gửi được 20 request (gấp đôi tải cho phép). Sliding window loại trừ lỗi này vì nó kiểm tra cửa sổ liên tục 60 giây gần nhất tính từ thời điểm gọi.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.
>
- Rate limit: Giới hạn số lượng/tần suất request trong một khoảng thời gian ngắn để bảo vệ hạ tầng máy chủ khỏi bị nghẽn và quá tải.
- Cost guard: Giới hạn tổng chi phí tài chính (USD) trong một chu kỳ dài để kiểm soát ngân sách LLM.
Tình huống minh họa:
1. Rate limit cho qua nhưng Cost guard chặn: User gửi 1 request duy nhất trong 15 phút, nhưng request này kèm prompt khổng lồ hàng chục nghìn token vượt quá ngân sách tháng còn lại của user -> Cost guard chặn.
2. Cost guard cho qua nhưng Rate limit chặn: User mới dùng đầu tháng, ngân sách còn 10 USD, gửi liên tục 15 request ngắn trong 5 giây (mỗi request chỉ tốn 0.0001 USD, tổng chi phí chỉ 0.0015 USD rất nhỏ) -> Cost guard cho qua nhưng Rate limit lập tức chặn với HTTP 429 vì spam request quá nhanh.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.
>
Thứ tự sự kiện:
1. Redis gặp sự cố mạng hoặc khởi động lại tạm thời trong 30 giây.
2. Endpoint gộp chung, kiểm tra Redis và thấy thất bại, cả 3 container agent đồng loạt trả về unhealthy.
3. Orchestrator nhận định cả 3 container đã hỏng và tiến hành kill + restart toàn bộ 3 container cùng lúc.
4. Khi Redis vừa khởi động lại xong sau 30 giây, 3 container agent lại đang trong trạng thái khởi động lại, dẫn đến toàn bộ hệ thống bị sập hoàn toàn và không còn instance nào phục vụ request.
Tách riêng giúp `/health` giữ container không bị restart oan, trong khi `/ready` báo cho load balancer tạm thời không đẩy traffic vào cho tới khi Redis online trở lại.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?
>
- Khi lưu trong Redis: Dù các request được round-robin phân bổ tới 3 container khác nhau, `history_length` luôn tăng đều (0, 2, 4, 6, ...) vì tất cả container đều đọc/ghi chung một cơ sở dữ liệu Redis.
- Nếu lưu trong dict Python: Mỗi container có vùng nhớ riêng biệt. Lần 1 gọi trúng container A (lưu câu hỏi 1), lần 2 gọi trúng container B (container B chưa có lịch sử nên `history_length` lại là 0). Người dùng sẽ thấy `history_length` nhảy hỗn loạn, agent bị "mất trí nhớ ngẫu nhiên" tùy vào việc request rơi vào container nào.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?
>
- Lỗi gặp phải: Chưa liên kết biến môi trường `REDIS_URL` từ service Redis sang service Agent trên Railway.
- Thông báo / Hiện tượng: Khi deploy thành công và kiểm tra endpoint `/ready`, service trả về `503 Service Unavailable` (`{"status": "not ready", "redis": false}`).
- Cách tìm nguyên nhân: Mở tab Variables của service Agent trên Railway dashboard, nhận thấy biến `REDIS_URL` đang dùng mặc định trỏ về `localhost` trong container (Do bản thân tôi bị nhầm lẫn).
- Cách sửa: Trong dashboard Railway, tại service Agent chọn "Variables" rồi tiếp tục chọn mục"Add Variable" để lấy biến `REDIS_URL` của redis server vừa được khởi tạo. Xác nhận deploy sau đó kiểm tra lại `/ready` trả về `200 {"status": "ready", "redis": true}`.

