namespace gravi_presentation.AuthConfiguration.Authentications.JwtAuthentications
{
    public class JwtOptions
    {
        public required string Issuer { get; set; }
        public required string Audience { get; set; }
        public required int LifeTime { get; set; }
        public required string SigningKey { get; set; }
    }
}
