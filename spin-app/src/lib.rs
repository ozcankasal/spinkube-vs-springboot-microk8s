use spin_sdk::http::{IntoResponse, Request, Response, Method};
use spin_sdk::http_service;

#[http_service]
async fn handle_spin_app(req: Request) -> anyhow::Result<impl IntoResponse> {
    let method = req.method();
    let path = req.uri().path();

    if method == &Method::GET && path == "/hello" {
        Ok(Response::builder()
            .status(200)
            .header("content-type", "text/plain")
            .body("Hello, World!".to_string()))
    } else if method == &Method::GET && path == "/compute" {
        let result = fibonacci(35);
        Ok(Response::builder()
            .status(200)
            .header("content-type", "text/plain")
            .body(format!("Fibonacci(35) = {}", result)))
    } else {
        Ok(Response::builder()
            .status(404)
            .header("content-type", "text/plain")
            .body("Not Found".to_string()))
    }
}

fn fibonacci(n: u32) -> u32 {
    if n <= 1 {
        return n;
    }
    fibonacci(n - 1) + fibonacci(n - 2)
}
