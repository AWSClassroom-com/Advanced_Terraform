// Lambda handler for Lab 3's serverless bonus module.
// Returns an env-tagged HTML page identical in shape to the EC2 module's
// /var/www/html/index.html, so the verification curl step produces the
// same comparison output regardless of which module deployed.

exports.handler = async (event) => {
    const env = process.env.ENVIRONMENT || "unknown";
    const user = process.env.USER_ID || "unknown";
    return {
        statusCode: 200,
        headers: { "Content-Type": "text/html" },
        body: `<h1>Sample Web App (Serverless)</h1>
<p>Environment: ${env}</p>
<p>User: ${user}</p>
<p>Deployed via Lambda + API Gateway HTTP API</p>`
    };
};
