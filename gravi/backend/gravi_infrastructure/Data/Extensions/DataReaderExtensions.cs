using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Data.Extensions
{
    public static class DataReaderExtensions
    {
        public static T Get<T>(this IDataRecord reader, string columnName)
        {
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? default! : (T)reader.GetValue(ordinal);
        }
    
    }
}
