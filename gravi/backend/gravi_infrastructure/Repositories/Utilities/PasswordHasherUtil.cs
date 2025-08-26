using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Repositories.Utilities
{
    public static class PasswordHasherUtil
    {
        private static readonly PasswordHasher<string> _hasher = new();

        public static string Hash(string password)
        {
            return _hasher.HashPassword("static", password);
        }

        public static bool Verify(string? hashedPassword, string? inputPassword)
        {
            if (hashedPassword == null || inputPassword == null) return false;

            var result = _hasher.VerifyHashedPassword("static", hashedPassword, inputPassword);
            return result == PasswordVerificationResult.Success ||
                   result == PasswordVerificationResult.SuccessRehashNeeded;
        }
    }
}
