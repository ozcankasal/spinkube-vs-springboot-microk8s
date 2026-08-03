# 🚀 Cloud-Native Dünyasında Bir Devrim mi? Kubernetes Üzerinde Spring Boot ile WebAssembly (SpinKube) Meydan Muharebesi

Mikroservisler ve Kubernetes (K8s) dünyası yıllardır aynı standart üzerine kurulu: Uygulamanı yaz, devasa bir Docker imajına (container) paketle ve cluster'a fırlat. Ancak bu "standart" yaklaşımın özellikle sunucu faturalarında yarattığı gizli bir kanama var: **Boşta tüketilen RAM'ler ve bitmek bilmeyen "Cold Start" (soğuk başlama) süreleri.**

Peki ya size uygulamanızın sıfır saniyede ayağa kalkıp, boştayken **hiçbir sistem kaynağı tüketmeyeceği**, ancak 10.000 istek geldiğinde saniyeler içinde binlerce kopyaya ulaşıp işi bitirebileceği bir gelecekten bahsetsem? 

İşte bu yazıda, geleneksel kurumsal dünyanın kralı **Java (Spring Boot)** ile geleceğin parlayan yıldızı **WebAssembly (SpinKube / Rust)** mimarilerini yerel bir **MicroK8s** cluster'ında ringe çıkartıyoruz.

Amacımız basit: Saf matematiksel yük altında hangisi daha hızlı? Ve daha da önemlisi, hangisi sunucu faturanızı kurtaracak?

---

### 🥊 Köşeleri Tanıyalım

**Kırmızı Köşe: Spring Boot (Java 21)**
Kurumsal dünyanın vazgeçilmezi. JIT (Just-In-Time) derleyicisi sayesinde muazzam bir çalışma zamanı hızına sahip. Ancak JVM (Java Sanal Makinesi) nedeniyle belleğe doymayan, hantal bir dev. Projemizde Spring Boot'u Docker deamon bile olmadan doğrudan Jib eklentisiyle paketleyip Kubernetes'e sürdük.

**Mavi Köşe: WebAssembly (Spin / Rust)**
Tarayıcılardan çıkıp sunucu tarafına sıçrayan Wasm teknolojisi. Uygulamalarınızı saniyeler değil, milisaniyeler içinde ayağa kaldıran, işletim sistemi bağımsız, ultra güvenli ve hafif bir mimari. Kubernetes tarafında bu modülleri standart bir pod gibi yönetmemizi sağlayan araç ise **SpinKube** (ve containerd-shim-spin).

*Test Senaryosu:* Her iki uygulamaya da klasik bir "Hello World" ve yoğun işlemci tüketen rekürsif bir Fibonacci (Fibonacci 35) hesaplama endpoint'i (`/compute`) yazdık.

---

### ⚙️ MicroK8s Üzerinde Çetin Bir Kurulum

Normalde bir Docker imajını K8s'te ayağa kaldırmak çocuk oyuncağıdır. Ancak K8s'e "Al bu bir Wasm dosyası, bunu çalıştır" diyemezsiniz (henüz). Bunun için MicroK8s'in kalbine, `containerd` seviyesine inip **SpinKube (Runtime Class Manager & Spin Operator)** kurulumları yaptık. 

Snap mimarisinin kısıtlamalarını aşıp, Wasm motorunu MicroK8s'e tanıttığımızda şu manzara ile karşılaştık:
- **Spring Boot:** Pod ayağa kalktı ve sadece hazırda beklemek (idle) için kendisine **130 MB RAM** ayırdı.
- **SpinApp:** Pod yaratıldı ama `kubectl top pods` komutunda görünmedi bile! Çünkü boşta tüketimi **~0 MB** idi.

---

### 🔥 Büyük Sınav: 10.000 İsteklik Yük Testi

Her iki uygulamayı da Apache Bench (`ab`) ile 100 eşzamanlı bağlantı (concurrency) altında tam 10.000 istekle dövdük. Amaç işlemciyi (CPU) %100 kapasiteye dayayıp, sınırları görmekti.

İşte o çarpıcı sonuçlar:

#### 1. Performans ve Hız (Kazanan: Spring Boot)
- **Spring Boot:** Saniyede ortalama **28 istek (Req/s)**. Testi 352 saniyede bitirdi.
- **Spin (WASM):** Saniyede ortalama **18 istek (Req/s)**. Testi 529 saniyede bitirdi.

*Neden böyle oldu?* Saf ve uzun süren matematiksel hesaplamalarda (rekürsif Fibonacci) Java'nın 25 yıllık JIT optimizasyonları devreye girdi. Döngüleri inanılmaz bir agresiflikle optimize eden JVM, işlemciyi daha verimli kullanarak Wasmtime motorunu bu spesifik testte geride bıraktı. 

#### 2. Kaynak Tüketimi ve Verimlilik (Kazanan: Spin/WASM - Açık Ara!)
- **Spring Boot Pik Tüketim:** 3.1 Çekirdek CPU | **261 MB RAM**
- **Spin (WASM) Pik Tüketim:** 3.1 Çekirdek CPU | **Sadece 87 MB RAM**

*İşte "Aha!" anı burada başlıyor.* CPU kullanımı iki tarafta da tavana vurduğu için istek süreleri saniyelere uzadı. Ancak asıl fark bellekteydi. En ağır darbede bile Spin, Spring Boot'un kullandığı belleğin sadece **üçte birini** kullandı!

---

### 💡 Sonuç ve Mimari Çıkarımlar: "Tekil Hız mı, Yatay Ölçeklenme mi?"

Eğer testi yaptığımız sunucuda JIT'in hızı sayesinde Spring Boot daha hızlıysa, neden WebAssembly diye bir şey var? Neden bu teknolojiye geleceğin Docker'ı gözüyle bakılıyor?

Cevap bulut mimarisindeki sihirli kelimede gizli: **Scale-out (Yatay Ölçeklenme)**.

Diyelim ki uygulamanız Black Friday günü bir trafik patlaması yaşadı ve Kubernetes 1.000 yeni Pod açmaya karar verdi:
- **Spring Boot seçtiyseniz:** 1.000 pod x 130 MB = **130 GB RAM**'e ihtiyacınız var demektir. Sadece bu kapasiteyi karşılamak için on binlerce dolar bulut faturası ödemeniz gerekir. Üstelik her bir JVM'in uyanması 3-5 saniye süreceği için o anki kullanıcılarınız hata sayfalarıyla boğuşacaktır.
- **Spin (WASM) seçtiyseniz:** 1.000 pod x 1 MB (başlangıç) = **Sadece 1 GB RAM!** Kıyıda köşede kalmış ucuz sunucularda bile devasa bir ordu kurabilirsiniz. Üstelik modüller milisaniyeler içinde ayağa kalktığı için müşteri hiçbir gecikme hissetmez. Trafik bittiğinde ise "Scale to Zero" (sıfıra ölçeklenme) ile RAM tüketimi tekrar 0'a iner.

#### Özetle;
Eğer video işleme, çok ağır saf veri analizi veya kriptografi gibi saatlerce sürecek "tekil" ve donanım sömüren bir işlem yapacaksanız, JIT/AOT derlemeli geleneksel diller (Java, C++, Rust-Native) hala kraldır. 

Ancak **saniyede on binlerce istek alan, Event-Driven (olay güdümlü) çalışan, Serverless (Sunucusuz) mimarilerde koşan** modern mikroservisler geliştiriyorsanız; WebAssembly (Spin) size faturanızı 10'da 1'ine düşürecek mikroskobik bir ayak izi ve ışık hızında ölçeklenme sunuyor.

Konteynerların altın çağı bitiyor olabilir mi? SpinKube ve WebAssembly'nin ayak sesleri, şimdiden bulut devlerinin koridorlarında yankılanıyor.

---

### 🏗️ PoC (Proof of Concept) Mimarimiz

Karşılaştırmanın adil ve gerçeğe en yakın senaryoda olabilmesi için her iki uygulamayı da aynı Kubernetes cluster'ı (MicroK8s) içerisine, dışarıdan HTTP istekleri alabilecek birer mikroservis olarak kurguladık.

1. **Local Kubernetes Ortamı:** Hızlı ve esnek olduğu için Canonical'ın **MicroK8s** çözümünü kullandık. İçerisinde yerel bir imaj deposu (Registry) ve CoreDNS barındırıyor.
2. **Spring Boot (Java 21):**
   - Framework: Spring Web (Sadece `/hello` ve `/compute` uç noktalarını sunan minimalist yapı)
   - Paketleme: **Jib Maven Plugin**. (Uygulamayı hantal Docker daemon'a ihtiyaç duymadan doğrudan OCI imajına dönüştürüp MicroK8s registry'sine atan daemonless bir yöntem kullandık.)
3. **SpinApp (WebAssembly / Rust):**
   - Framework: Fermyon Spin (v3) ve Rust SDK (`spin-sdk v6.0.0`)
   - Çalışma Ortamı (Runtime): Kubernetes üzerinde WASM modüllerini standart bir pod gibi yöneten **SpinKube (v0.6.1)**. 
   - Konteyner Motoru Eklentisi: `containerd-shim-spin-v2` (WASM dosyalarını Linux container mantığı olmadan doğrudan işletim sisteminde güvenle çalıştıran köprü).

---

### 🛠️ Kendi Cluster'ınızda Nasıl Denersiniz? (Kurulum Adımları)

Eğer siz de bu büyüyü kendi makinenizde test etmek isterseniz, PoC süresince otomatize ettiğimiz adımları aşağıda bulabilirsiniz. (Önkoşul: Ubuntu tabanlı bir Linux ve kurulu bir MicroK8s ortamı).

#### 1. MicroK8s Hazırlığı ve SpinKube Altyapısının Kurulması
Normal şartlarda Kubernetes sadece Linux container'larını (`docker` veya `containerd`) tanır. K8s'e WebAssembly dilini öğretmek için SpinKube operatörlerini kurmamız gerekiyor.

```bash
# Gerekli eklentileri aktif edelim
microk8s enable dns registry helm3 metrics-server

# Spin için Runtime Class Manager ve Shim (WASM Köprüsü) kurulumu
kubectl apply -f https://github.com/spinframework/containerd-shim-spin/releases/download/v0.25.1/runtime-class-manager-shim-v1alpha1-v0.25.1.yaml

# Node'umuzu "WASM çalıştırabilir" olarak etiketliyoruz
kubectl label node --all spin=true --overwrite
```

**Kritik MicroK8s Dokunuşu:** MicroK8s, snap izolasyonu (sandbox) nedeniyle standart dizinleri okumaz. Wasm motorunu MicroK8s'in `containerd` config dosyasına manuel olarak tanıtmalısınız:
```bash
# Wasm shim dosyasını standart yola çekelim
curl -LO https://github.com/spinframework/containerd-shim-spin/releases/download/v0.25.1/containerd-shim-spin-v2-linux-x86_64.tar.gz
sudo tar -C /usr/local/bin -xzf containerd-shim-spin-v2-linux-x86_64.tar.gz

# MicroK8s containerd ayarlarına Wasm'ı deklare edip servisi yeniden başlatalım
echo '[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.spin]
  runtime_type = "io.containerd.spin.v2"' | sudo tee -a /var/snap/microk8s/current/args/containerd-template.toml
  
microk8s stop && microk8s start
```

#### 2. Spin Operator Kurulumu
Kubernetes'in `SpinApp` ismindeki özel kaynak tipini (CRD) anlayabilmesi için Spin Operator'ı kuruyoruz:

```bash
kubectl apply -f https://github.com/spinframework/spin-operator/releases/download/v0.6.1/spin-operator.shim-executor.yaml
helm upgrade --install spin-operator --namespace spin-operator --create-namespace --version 0.6.1 oci://ghcr.io/spinframework/charts/spin-operator
```

#### 3. Uygulamaların Deploy Edilmesi
Artık ortamımız hazır. Repomuzdaki iki uygulamayı da derleyip MicroK8s üzerine gönderebiliriz.

**Spring Boot İçin:**
Sıfır Docker kurulumuyla, doğrudan Jib üzerinden imajı inşa edip MicroK8s registry'sine (localhost:32000) itiyoruz:
```bash
cd springboot-app
mvn compile jib:build \
  -Djib.to.image=localhost:32000/springboot-app:latest \
  -Djib.allowInsecureRegistries=true
  
kubectl apply -f k8s/springboot-deployment.yaml
```

**Spin (WASM) İçin:**
Rust ile yazdığımız WASM modülünü derliyor ve Spin CLI ile registry'e yolluyoruz:
```bash
cd spin-app
spin build
spin registry push --insecure localhost:32000/spin-app:latest

kubectl apply -f k8s/spinapp.yaml
```

*Not: Spin uygulamasını deploy ederken klasik bir `Deployment` yaml'ı yerine, türü `SpinApp` olan özel bir manifest kullanıyoruz.*

#### 4. Yük Testi (Load Testing) Aracı
Performansı ölçmek için `apache2-utils` (Apache Bench) kullandık. Test ortamını başlatmak çok basit:

```bash
# Servis IP'lerini yakalayalım
SPRING_IP=$(kubectl get svc springboot-app-service -o jsonpath='{.spec.clusterIP}')
SPIN_IP=$(kubectl get svc spin-app-service -o jsonpath='{.spec.clusterIP}')

# 10.000 isteği 100 eşzamanlı kullanıcı (concurrency) ile başlatalım
ab -n 10000 -c 100 "http://$SPRING_IP:8080/compute"
ab -n 10000 -c 100 "http://$SPIN_IP:80/compute"
```
Test çalışırken farklı bir sekmede `microk8s kubectl top pods` komutunu izleyerek o devasa RAM tüketimi farkına kendi gözlerinizle şahit olabilirsiniz.

---

### Kapanış Notları ve Gelecek
WebAssembly (WASM) sadece tarayıcılar için icat edilmiş gibi görünse de, sunucu tarafında (Server-side) sessiz bir devrim yaratıyor. Docker konteynerlarının getirdiği izolasyon ve paketleme rahatlığını, milisaniyelik açılış süreleri ve KB seviyesinde boyutlarla harmanlıyor.

Elbette Java ve Spring Boot ölmüyor; karmaşık veritabanı işlemleri, stateful (durum tutan) devasa monolith yapıları ve uzun soluklu veri işleme süreçlerinde JIT derleyicisi gücüyle uzun yıllar tahtını koruyacak.

Ancak bulut mimarisinde "Mikroservisler" yavaş yavaş **"Nano-servislere"** doğru evrilirken, faturalarını düşürmek ve trafik patlamalarında anında ölçeklenmek isteyen şirketler için SpinKube ve WebAssembly ikilisi çok yakında endüstri standardı haline gelebilir. 

*Gelecek, konteynerlarda değil, modüllerde saklı olabilir.*
