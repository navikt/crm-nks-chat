@IsTest
public class NKS_RequestMock implements HttpCalloutMock {
    private String endpoint;
    private String method;
    private Integer statusCode;
    private String body;
    private Boolean throwCallout;
    public Integer calls = 0;

    public NKS_RequestMock(String endpoint, String method, Integer statusCode, String body) {
        this.endpoint = endpoint;
        this.method = method;
        this.statusCode = statusCode;
        this.body = body;
        this.throwCallout = false;
    }

    public NKS_RequestMock throwing() {
        throwCallout = true;
        return this;
    }

    public HttpResponse respond(HttpRequest request) {
        calls++;
        Assert.areEqual(endpoint, request.getEndpoint());
        Assert.areEqual(method, request.getMethod());
        Assert.areEqual('application/json', request.getHeader('Content-Type'));
        Assert.isTrue(String.isBlank(request.getBody()), 'These API operations must not send a body');
        if (throwCallout) {
            throw new CalloutException('Simulated participant callout failure');
        }
        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setBody(body);
        return response;
    }
}
